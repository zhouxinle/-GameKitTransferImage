//
//  ImageTransferViewController.m
//  ImageTransfer
//
//  Created by Alex Nichol on 11/7/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import "ImageTransferViewController.h"
#import "ANLoadingManager.h"

#define kSessionID @"imgtrnsfr"

static NSUInteger const fileBlockSize = 1024;

@implementation ImageTransferViewController

@synthesize mSession;
@synthesize tmpSession;
@synthesize peerID;
@synthesize mPicker;

- (void)makeNewConnection {
	self.mPicker = [[[GKPeerPickerController alloc] init] autorelease];
	mPicker.delegate = self;
	mPicker.connectionTypesMask = GKPeerPickerConnectionTypeNearby;	
	[mPicker show];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.delegate = self;
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	[self makeNewConnection];
    
    flag = 0;
    totalImageData = [[NSMutableData alloc]init];

}

#pragma mark Image Sending

//发送图片，从相册中选择图片
- (IBAction)sendImage:(id)sender {
	[self presentModalViewController:imagePickerController animated:YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker 
		didFinishPickingImage:(UIImage *)image
				  editingInfo:(NSDictionary *)editingInfo 
{
    [picker dismissModalViewControllerAnimated:YES];
	// use image
	[[ANLoadingManager sharedManager] startLoadingObject:nil withJobSelector:0 
												userInfo:nil];
    
    NSData* imageData = UIImageJPEGRepresentation(image, 1.0);
    NSLog(@"imageData.length = %d",imageData.length);
    NSUInteger num = (imageData.length % fileBlockSize) == 0  ? 0 : 1;
    blockNums = (NSUInteger)(imageData.length / fileBlockSize) +  num;
//    NSDictionary* blockNumsDic = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:blockNums],@"blockNums", nil];
    NSString* blockNumsString = [NSString stringWithFormat:@"%d",blockNums];
    NSData* blockNumsData = [blockNumsString dataUsingEncoding:NSUTF8StringEncoding];
    NSError* error = nil;
    [self.mSession sendData:blockNumsData toPeers:[NSArray arrayWithObjects:self.peerID, nil] withDataMode:GKSendDataReliable error:&error];
    if (error) {
        NSLog(@"error = %@",error);
    }
    
    NSData *dataToSend;
    NSRange range = {0, 0};
    for(NSUInteger i=1;i<blockNums;i++)
    {
        range = NSMakeRange((i-1)*fileBlockSize, fileBlockSize);
        dataToSend = [imageData subdataWithRange:range];
        //send 'dataToSend'
        [self.mSession sendData:dataToSend toPeers:[NSArray arrayWithObjects:self.peerID, nil] withDataMode:GKSendDataReliable error:&error];
        if (error) {
            NSLog(@"error = %@",error);
        }
    }
    NSUInteger remainder = (imageData.length % fileBlockSize);
    if (remainder != 0){
        range = NSMakeRange(imageData.length - remainder,remainder);
        dataToSend = nil;
        //range = {imageData.length - remainder,remainder};
        dataToSend = [imageData subdataWithRange:range];
        //send 'dataToSend'
        [self.mSession sendData:dataToSend toPeers:[NSArray arrayWithObjects:self.peerID, nil] withDataMode:GKSendDataReliable error:&error];
        if (error) {
            NSLog(@"error = %@",error);
        }
    }
    [[ANLoadingManager sharedManager] doneTask];

    
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	// ignore
	[picker dismissModalViewControllerAnimated:YES];
}

#pragma mark Peer Picking

- (IBAction)disconnect:(id)sender {
	[self.mSession disconnectFromAllPeers];
	self.tmpSession = nil;
	self.mSession = nil;
	[self makeNewConnection];
}

- (void)peerPickerControllerDidCancel:(GKPeerPickerController *)picker {
	exit(0);
}

- (GKSession *)peerPickerController:(GKPeerPickerController *)picker sessionForConnectionType:(GKPeerPickerConnectionType)type {
    //创建会话！
	GKSession * session = [[GKSession alloc] initWithSessionID:kSessionID displayName:nil sessionMode:GKSessionModePeer]; 
	return [session autorelease]; // peer picker retains a reference, so autorelease ours so we don't leak.
}

- (void)peerPickerController:(GKPeerPickerController *)picker didConnectPeer:(NSString *)_peerID toSession:(GKSession *)session {
	// Use a retaining property to take ownership of the session.
    self.mSession = session;
	self.mSession.delegate = self;
    [self.mSession setDataReceiveHandler:self withContext:nil];
    
//	self.tmpSession = [[[TCSession alloc] init] autorelease];
//	[self.tmpSession setSession:session];
//	self.tmpSession.delegate = self;
    
	// Remove the picker.
	self.mPicker.delegate = nil;
    [self.mPicker dismiss];
	[mPicker autorelease];
	mPicker = nil;
    
    //对方peerID
	self.peerID = _peerID;
}

- (void)receiveData:(NSData *)data fromPeer:(NSString *)peer inSession:(GKSession *)session context:(void *)context
{

    if (flag == 0) {
        [[ANLoadingManager sharedManager] startLoadingObject:nil withJobSelector:0
                                                    userInfo:nil];
        NSString* receiveBlockNumsString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        receiveBlockNums = [receiveBlockNumsString integerValue];
        flag ++;
    }
    else{
       
            // Receive data
        [totalImageData appendData:data];
        
        if (flag == receiveBlockNums) {
           	[[ANLoadingManager sharedManager] doneTask];
            NSLog(@"totalImageData = %d",totalImageData.length);
            UIImage * image = [[UIImage alloc] initWithData:totalImageData];
            ImageViewController * ivc = [[ImageViewController alloc] initWithNibName:@"ImageViewController" bundle:nil];
            [ivc setImage:image];
            [self presentModalViewController:ivc animated:YES];
            [ivc release];
            [image release];
            
            return;
        }
        flag ++;
        
    }
    
    
}

#pragma mark GameKit and TCPacket

//会话状态变化的回调
- (void)session:(GKSession *)session peer:(NSString *)_peerID didChangeState:(GKPeerConnectionState)state {
	switch (state)
    {
        case GKPeerStateConnected:
		{
			// great
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.5];
			[multiplayerView setAlpha:1];
			[UIView commitAnimations];
			NSLog(@"Connected.");
			break;
		}
        case GKPeerStateDisconnected:
		{
			//self.tmpSession = nil;
			self.mSession = nil;
			[self makeNewConnection];
			break;
		}
    }
}

- (void)tcsession:(id)sender couldNotHandleDataFromPeer:(NSString *)peerID {
	[[ANLoadingManager sharedManager] doneTask];
}

//完全接受到数据
- (void)tcsession:(id)sender recievedData:(NSData *)d fromPeer:(NSString *)peerID {
	// got an image
	[[ANLoadingManager sharedManager] doneTask];
	UIImage * image = [[UIImage alloc] initWithData:d];
	ImageViewController * ivc = [[ImageViewController alloc] initWithNibName:@"ImageViewController" bundle:nil];
	[ivc setImage:image];
	[self presentModalViewController:ivc animated:YES];
	[ivc release];
	[image release];
}

//结束发送数据
- (void)tcsessionFinishedSendingData:(id)sender {
	[[ANLoadingManager sharedManager] doneTask];
}

//开始接受数据
- (void)tcsession:(id)sender startGettingDataFromPeer:(NSString *)peerID {
	[[ANLoadingManager sharedManager] startLoadingObject:nil
										 withJobSelector:0 userInfo:nil];
}

#pragma mark Memory Management

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
	self.mPicker = nil;
	self.tmpSession = nil;
	self.mPicker = nil;
	self.peerID = nil;
    [super dealloc];
}

@end
