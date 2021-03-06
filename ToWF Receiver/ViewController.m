//
//  ViewController.m
//  ToWF Receiver
//
//  Created by Mark Briggs on 12/1/14.
//  Copyright (c) 2014 Mark Briggs. All rights reserved.
//

#import "ViewController.h"
#import "Util.h"
#import "GCDAsyncUdpSocket.h"
#import "DatagramChannel.h"
#import "LangPortPairs.h"
#import "PcmAudioDataPayload.h"
#import "SeqId.h"
#import "PayloadStorageList.h"
#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>
@import SystemConfiguration.CaptiveNetwork;


#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

#define INFO_PORT_NUMBER 7769

// Broadcast
#define DG_DATA_HEADER_LENGTH 6  // Bytes

// UDP PACKET
#define UDP_PACKET_SIZE 512
#define UDP_HEADER_SIZE 8
#define IPV4_HEADER_SIZE 20
#define ETH_HEADER_SIZE 14
#define UDP_DATA_SIZE (UDP_PACKET_SIZE - UDP_HEADER_SIZE - IPV4_HEADER_SIZE - ETH_HEADER_SIZE) //512-42=470
#define UDP_DATA_PAYLOAD_SIZE (UDP_DATA_SIZE - DG_DATA_HEADER_LENGTH)  //470-6=464

// Audio Datagram Constants
#define DG_DATA_HEADER_ID_START 0  // "ToWF"
#define DG_DATA_HEADER_ID_LENGTH 4
#define DG_DATA_HEADER_RSVD0_START 4
#define DG_DATA_HEADER_RSVD0_LENGTH 1
#define DG_DATA_HEADER_PAYLOAD_TYPE_START 5
#define DG_DATA_HEADER_PAYLOAD_TYPE_LENGTH 1

// Audio Data Datagram (port 7770-777x)
#define DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_FORMAT 0
#define DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA_REGULAR 1
// Info Datagram (port 7769)
#define DG_DATA_HEADER_PAYLOAD_TYPE_LANG_PORT_PAIRS 2  // NOTE: Payload Types don't need to be unique across different PORTs, but I'm making them unique just to keep them a bit easier to keep track of.
#define DG_DATA_HEADER_PAYLOAD_TYPE_CLIENT_LISTENING 3
#define DG_DATA_HEADER_PAYLOAD_TYPE_MISSING_PACKETS_REQUEST 4
#define DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA_MISSING 5
#define DG_DATA_HEADER_PAYLOAD_TYPE_ENABLE_MPRS 6
#define DG_DATA_HEADER_PAYLOAD_TYPE_CHAT_MSG 7
#define DG_DATA_HEADER_PAYLOAD_TYPE_RLS 8  // Request Listening State


// OS Constants
#define OS_OTHER 0
#define OS_IOS 1
#define OS_ANDROID 2

// Audio Format Related
#define AFDG_SAMPLE_RATE_START (DG_DATA_HEADER_LENGTH + 0)
#define AFDG_SAMPLE_RATE_LENGTH 4

#define AF_SAMPLE_SIZE_IN_BITS 16
#define AF_CHANNELS 1
#define AF_SIGNED YES
#define AF_BIG_ENDIAN NO

#define AF_SAMPLE_SIZE_IN_BYTES 2
#define AF_FRAME_SIZE (AF_SAMPLE_SIZE_IN_BYTES * AF_CHANNELS)
#define AUDIO_DATA_MAX_VALID_SIZE (ADPL_AUDIO_DATA_AVAILABLE_SIZE - (ADPL_AUDIO_DATA_AVAILABLE_SIZE % AF_FRAME_SIZE))

// Audio Data Payload Constants
#define ADPL_AUDIO_DATA_AVAILABLE_SIZE (UDP_DATA_PAYLOAD_SIZE - ADPL_HEADER_LENGTH)

// Lang/Port Pairs Constants
#define LPP_NUM_PAIRS_START (DG_DATA_HEADER_LENGTH + 0)
#define LPP_NUM_PAIRS_LENGTH 1
#define LPP_RSVD0_START (DG_DATA_HEADER_LENGTH + 1)
#define LPP_RSVD0_LENGTH 1
#define LPP_SERVER_VERSION_START (DG_DATA_HEADER_LENGTH + 2)
#define LPP_SERVER_VERSION_LENGTH 10
#define LPP_LANG0_START (DG_DATA_HEADER_LENGTH + 12)
#define LPP_LANG_LENGTH 16
#define LPP_PORT0_START (DG_DATA_HEADER_LENGTH + 28)
#define LPP_PORT_LENGTH 2

// Client Listening Payload
#define CLPL_IS_LISTENING_START (DG_DATA_HEADER_LENGTH + 0)
#define CLPL_IS_LISTENING_LENGTH 1
#define CLPL_OS_TYPE_START (DG_DATA_HEADER_LENGTH + 1)
#define CLPL_OS_TYPE_LENGTH 1
#define CLPL_PORT_START (DG_DATA_HEADER_LENGTH + 2)
#define CLPL_PORT_LENGTH 2
#define CLPL_OS_VERSION_STR_START (DG_DATA_HEADER_LENGTH + 4)
#define CLPL_OS_VERSION_STR_LENGTH 8
#define CLPL_HW_MANUFACTURER_STR_START (DG_DATA_HEADER_LENGTH + 12)
#define CLPL_HW_MANUFACTURER_STR_LENGTH 16
#define CLPL_HW_MODEL_STR_START (DG_DATA_HEADER_LENGTH + 28)
#define CLPL_HW_MODEL_STR_LENGTH 16
#define CLPL_USERS_NAME_START (DG_DATA_HEADER_LENGTH + 44)
#define CLPL_USERS_NAME_LENGTH 32

// Missing Packets Request Payload
#define MPRPL_NUM_MISSING_PACKETS_START (DG_DATA_HEADER_LENGTH + 0)
#define MPRPL_NUM_MISSING_PACKETS_LENGTH 1
#define MPRPL_RSVD0_START (DG_DATA_HEADER_LENGTH + 1)
#define MPRPL_RSVD0_LENGTH 1
#define MPRPL_PORT_START (DG_DATA_HEADER_LENGTH + 2)
#define MPRPL_PORT_LENGTH 2
#define MPRPL_PACKET0_SEQID_START (DG_DATA_HEADER_LENGTH + 4)
#define MPRPL_PACKET_SEQID_LENGTH 2
#define MPRPL_PACKETS_AVAILABLE_SIZE (UDP_DATA_SIZE - DG_DATA_HEADER_LENGTH - MPRPL_NUM_MISSING_PACKETS_LENGTH - MPRPL_RSVD0_LENGTH - MPRPL_PORT_LENGTH)

// Enable MPRs (Missing Packet Requests)
#define ENMPRS_ENABLED_START (DG_DATA_HEADER_LENGTH + 0)
#define ENMPRS_ENABLED_LENGTH 1

// Chat Msg
#define CHATMSG_MSG_START (DG_DATA_HEADER_LENGTH + 0)


#define SERVER_STREAMING_CHECK_TIMER_INTERVAL 4.0  // Check if at least 1 audio data packet has been received in the last X seconds.
#define RECEIVING_AUDIO_CHECK_TIMER_INTERVAL 0.2  // 0.2 => 5 fps "refresh rate"

#define FAST_PLAYBACK_SPEED 1.2
#define SLOW_PLAYBACK_SPEED 0.8

//#define MPR_DELAY_RESET 5  // Number(X) of Frames that we must receive, where all X Frame are NOT the first missing packet in our payloadStorageList. If mprDelayTimer reaches 0, THEN we'll send MissingPacketRequest (if any)


@interface ViewController ()
{
    BOOL isListening;
    
    GCDAsyncUdpSocket *udpSocket;
    GCDAsyncUdpSocket *infoSocket;  // listens to "info" on port 7769 (e.g. lang/port pairs)

    NSMutableString *log;
    
    float maxAudioDelaySecs;
    
    // Audio Format
    float afSampleRate;
    BOOL isAudioFormatValid;

    // Audio Format - Derived
    int packetRateMS;
    
    NSTimeInterval burstModeWatchdogTimerTimeout;
    
    long numReceivedAudioDataPackets;
    long lastNumReceivedAudioDataPackets;
    SeqId *lastQueuedSeqId;
    Boolean firstPacketReceived;
    
    float playbackRate;
    BOOL playFaster;
    BOOL playSlower;
    
    UIColor *colorVeryLightGray;
    UIColor *colorGreen;
    UIColor *colorYellow;
    UIColor *colorRed;
    UIColor *colorBlue;
    
    LangPortPairs *langPortPairs;
    UIPickerView *langPicker;
    
    BOOL isServerStreaming;
    BOOL receivedAPacket;
    NSTimer *serverStreamingCheckTimer;
    BOOL isReceivingAudio;
    BOOL receivedAnAudioPacket;
    NSTimer *receivingAudioCheckTimer;
    
    BOOL isReloadingCircularBuffer;
    
    int streamPort;
    
    NSString *serverHostIp;
    uint16_t audioDataPort;
    
    dispatch_queue_t handleUdpDataQueue;
    
    PayloadStorageList *payloadStorageList;
    
    SeqId *highestMissingSeqId;
    Boolean isWaitingOnMissingPackets;

    Boolean isBurstMode;
    NSTimer *burstModeWatchdogTimer;
    
    NSTimer *wifiSsidTimer;
    NSString *prevSSID;
    
    AVAudioPlayer *dripSoundPlayer;
    
    NSString *appVersionStr;
    
}

@property (weak, nonatomic) IBOutlet UILabel *wifiConnection;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIButton *btnStartStop;
@property (weak, nonatomic) IBOutlet UILabel *lblReceivingAudio;
@property (weak, nonatomic) IBOutlet UILabel *lblPlaybackSpeed;
@property (weak, nonatomic) IBOutlet UITextField *tfMaxAudioDelaySecs;
@property (weak, nonatomic) IBOutlet UILabel *waitingForServerLabel;
@property (weak, nonatomic) IBOutlet UIView *streamView;
@property (weak, nonatomic) IBOutlet UIView *listeningView;
@property (weak, nonatomic) IBOutlet UITextField *languageTF;
@property (weak, nonatomic) IBOutlet UISlider *desiredDelaySlider;
@property (weak, nonatomic) IBOutlet UILabel *desiredDelayLabel;
@property (weak, nonatomic) IBOutlet UISwitch *sendMissingPacketsRequestsSwitch;
@property (weak, nonatomic) IBOutlet UITextField *chatMsgTF;
@property (nonatomic, strong) AEAudioController *audioController;
@property (nonatomic, strong) DatagramChannel *dgChannel;
@property (nonatomic, strong) AEAudioUnitFilter *timePitchFastFilter;
@property (nonatomic, strong) AEAudioUnitFilter *timePitchSlowFilter;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Init lots of stuff
    log = [[NSMutableString alloc] init];

    // UDP Socket
    udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    [udpSocket setIPv4Enabled:YES];
    [udpSocket setIPv6Enabled:NO];  // Must do this for broadcast packets cuz, for whatever reason, even if just 1 packet is received, udpSocket:didReceiveData:... will get called once for EACH IPv4 and IPv6!, resulting in twice as many packets getting received.
    
    // Info Socket
    infoSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [infoSocket setIPv4Enabled:YES];
    [infoSocket setIPv6Enabled:NO];
    NSError *error = nil;
    if (![infoSocket bindToPort:INFO_PORT_NUMBER error:&error]) {
        [self logError:FORMAT(@"Error binding to port for infoSocket: %@", error)];
        NSLog(@"Error binding to port for infoSocket: %@", error);
        return;
    }
    if (![infoSocket beginReceiving:&error]) {
        [infoSocket close];
        [self logError:FORMAT(@"Error beginReceiving for infoSocket: %@", error)];
        NSLog(@"Error beginReceiving for infoSocket: %@", error);
        return;
    }
    //[self logInfo:FORMAT(@"Listening for INFO on port: %hu", [infoSocket localPort])];
    NSLog(@"Listening for INFO on port: %hu", [infoSocket localPort]);
    
    maxAudioDelaySecs = 0.25;  // Default
    
    isAudioFormatValid = NO;
    playbackRate = 1.0;  // 1x speed.
    playFaster = NO;
    afSampleRate = 0;

    colorVeryLightGray = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1];
    colorGreen = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
    colorRed = [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
    colorBlue = [UIColor colorWithRed:0 green:0 blue:1 alpha:1];
    colorYellow = [UIColor colorWithRed:0.75 green:0.75 blue:0 alpha:1];
    
    numReceivedAudioDataPackets = 0;
    lastNumReceivedAudioDataPackets = 0;

    // Create our datagram channel just once.
    self.dgChannel = [[DatagramChannel alloc] init];
    
    // Fill in Wi-Fi Connection Label (note: also do in onAppEnteredForeground:)
    NSDictionary *ssidInfo = [self fetchSSIDInfo];
    NSString *ssidStr = ssidInfo[@"SSID"];
    NSLog(@"ssidStr: %@", ssidStr);
    [self setWifiConnectionLabel:ssidStr];

    // Setup UIPicker view for displaying selectable languages
    langPicker = [[UIPickerView alloc] init];
    langPicker.dataSource = self;
    langPicker.delegate = self;
    self.languageTF.inputView = langPicker;
    
    serverHostIp = @"";
    audioDataPort = 0;
    
    // Language/Port pairs
    langPortPairs = [[LangPortPairs alloc] init];
    
    // observer checks if we're back from the background
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    isReloadingCircularBuffer = NO;
    
    self.streamView.hidden = YES;
    self.listeningView.hidden = YES;
    
    isListening = NO;
    
    _webView.dataDetectorTypes = UIDataDetectorTypeNone;
    
    handleUdpDataQueue = dispatch_queue_create("com.briggs-inc.towf-receiver.HandleUdpDataQueue", NULL);
    
    payloadStorageList = [[PayloadStorageList alloc] init];
    
    highestMissingSeqId = [[SeqId alloc] initWithInt:0];
    isWaitingOnMissingPackets = NO;
    isBurstMode = NO;
    
    serverStreamingCheckTimer = [NSTimer scheduledTimerWithTimeInterval:SERVER_STREAMING_CHECK_TIMER_INTERVAL target:self selector:@selector(checkServerStoppedStreaming) userInfo:nil repeats:YES];
    receivingAudioCheckTimer = [NSTimer scheduledTimerWithTimeInterval:RECEIVING_AUDIO_CHECK_TIMER_INTERVAL target:self selector:@selector(checkReceivingAudio) userInfo:nil repeats:YES];
    
    isServerStreaming = NO;
    isReceivingAudio = NO;
    
    wifiSsidTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(checkWifiSsidChange) userInfo:nil repeats:YES];
    prevSSID = @"";
    
    // Setup the 'drip' sound player
    NSError *err;
    NSString *dripPath = [NSString stringWithFormat:@"%@/drip.mp3", [[NSBundle mainBundle] resourcePath]];
    NSURL *dripUrl = [NSURL fileURLWithPath:dripPath];
    dripSoundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:dripUrl error:&err];
    if (err != nil) {
        NSLog(@"ERROR with dripSoundPlayer: %@", err);
    }
    
    appVersionStr = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    // Add version # to label in GUI
    self.versionLabel.text = [NSString stringWithFormat:@"(v%@)", appVersionStr];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (IBAction)startStopListening:(id)sender {
    NSLog(@"onStartStopListening()");
    [self.view endEditing:YES];  // Hide keyboard
    
    if (isListening)
    {
        [self onStopListening];
    }
    else
    {
        [self onStartListening];
    }
}

- (IBAction)onSendChatMsgClicked:(id)sender {
    //[self.chatMsgTF resignFirstResponder];
    //[self sendChatMsg];
    [self processOutgoingChatMsg];
}

- (void)onStopListening {
    NSLog(@"onStopListening()");
    
    // Stop Audio Controller
    [_audioController stop];
    
    // Flush circular buffer
    [self.dgChannel flushBuffer];
    
    // Stop Socket-related
    [udpSocket close];
    
    //[self logInfo:@"Stopped Listening"];
    //NSLog(@"Stopped Listening");
    isListening = NO;
    
    [self sendClientListeningWithIsListening:isListening Port:streamPort];
    
    self.listeningView.hidden = YES;
    [_btnStartStop setTitle:@"Start Listening" forState:UIControlStateNormal];
}

- (void)onStartListening {
    NSLog(@"onStartListening()");
    
    // Read max audio delay from GUI
    maxAudioDelaySecs = [self.tfMaxAudioDelaySecs.text floatValue];
    //NSLog(@"maxAudioDelaySecs: %f", maxAudioDelaySecs);
    
    // Start or Create/Start Audio Controller
    if (self.audioController != nil) {
        [self startAudioController];
    } else {
        [self createAndStartNewAudioControllerAndSetup];
    }
    
    // Packet Recovery Related
    firstPacketReceived = NO;  // To specify that we just started (so we don't think that we just skipped 100 or 1000 packets)
    [payloadStorageList removeAllPayloads];
    
    // Setup Socket-related things
    streamPort = [langPortPairs getPortForLanguage:self.languageTF.text];
    
    if (streamPort < 0 || streamPort > 65535)
    {
        streamPort = 0;
    }
    
    NSError *error = nil;
    if (![udpSocket bindToPort:streamPort error:&error])
    {
        [self logError:FORMAT(@"Error binding udpSocket to port: %d, error: %@", streamPort, error)];
        return;
    }
    if (![udpSocket beginReceiving:&error])
    {
        [udpSocket close];
        [self logError:FORMAT(@"Error starting server (recv): %@", error)];
        return;
    }
    
    //[self logInfo:FORMAT(@"Started listening on port: %hu", [udpSocket localPort])];
    NSLog(@"Started listening on port: %hu", [udpSocket localPort]);
    isListening = YES;
    if (!isAudioFormatValid) {
        //[self logInfo:FORMAT(@"Waiting for Audio Format packet...")];
        NSLog(@"Waiting for Audio Format packet...");
    }
    
    
    // For Debug
    ////NSLog(@"uniqueIdentifier: %@", [[UIDevice currentDevice] uniqueIdentifier]);
    /*
    NSLog(@"name: %@", [[UIDevice currentDevice] name]);
    NSLog(@"systemName: %@", [[UIDevice currentDevice] systemName]);
    NSLog(@"systemVersion: %@", [[UIDevice currentDevice] systemVersion]);
    NSLog(@"model: %@", [[UIDevice currentDevice] model]);
    NSLog(@"localizedModel: %@", [[UIDevice currentDevice] localizedModel]);
    */
    
    [self sendClientListeningWithIsListening:isListening Port:streamPort];
    
    self.listeningView.hidden = NO;
    [_btnStartStop setTitle:@"Stop Listening" forState:UIControlStateNormal];
}

-(void)sendClientListeningWithIsListening:(Boolean)clIsListening Port:(int)port {
    
    // Send to server the "Client Listening" packet
    NSMutableData *clData = [[NSMutableData alloc]init];

    [Util appendInt:0x546F5746 OfLength:4 ToData:clData BigEndian:YES]; // "ToWF"
    [Util appendInt:0 OfLength:1 ToData:clData BigEndian:NO];  // Rsvd
    [Util appendInt:DG_DATA_HEADER_PAYLOAD_TYPE_CLIENT_LISTENING OfLength:1 ToData:clData BigEndian:NO];  // Payload Type
    
    // IsListening
    [Util appendInt:clIsListening ? 1 : 0 OfLength:CLPL_IS_LISTENING_LENGTH ToData:clData BigEndian:NO];
    
    // OS Type
    [Util appendInt:OS_IOS OfLength:CLPL_OS_TYPE_LENGTH ToData:clData BigEndian:NO];
    
    // Port
    [Util appendInt:port OfLength:CLPL_PORT_LENGTH ToData:clData BigEndian:NO];
    
    // OS Version
    NSString *osVer = [[UIDevice currentDevice] systemVersion];
    [Util appendNullTermString:osVer ToData:clData MaxLength:CLPL_OS_VERSION_STR_LENGTH PadWith0s:YES];
    
    // HW Manufacturer
    [Util appendNullTermString:@"Apple" ToData:clData MaxLength:CLPL_HW_MANUFACTURER_STR_LENGTH PadWith0s:YES];
    
    // HW Model
    [Util appendNullTermString:deviceName() ToData:clData MaxLength:CLPL_HW_MODEL_STR_LENGTH PadWith0s:YES];
    
    // Users Name / Device Name
    [Util appendNullTermString:[[UIDevice currentDevice] name] ToData:clData MaxLength:CLPL_USERS_NAME_LENGTH PadWith0s:YES];
    
    // Now, send the CL packet to server
    [infoSocket sendData:clData toHost:serverHostIp port:INFO_PORT_NUMBER withTimeout:-1 tag:0];
}

-(void)sendMissingPacketsRequestWithPort:(int)port AndMissingPayloads:(NSArray*)missingPayloads {
    // Send 1 (or more, if needed) Missing Packets Request
    
    if (missingPayloads.count <= 0) {
        return;  // Don't send anything if we don't have missing packets
    }
    
    int remainingMissingPacketsToSend = (int)missingPayloads.count;
    while (remainingMissingPacketsToSend > 0) {
        int currNumMissingPacketsToSend = MIN(remainingMissingPacketsToSend, MPRPL_PACKETS_AVAILABLE_SIZE/2);
        
        NSMutableData *mprData = [[NSMutableData alloc]init];
        
        [Util appendInt:0x546F5746 OfLength:4 ToData:mprData BigEndian:YES]; // "ToWF"
        [Util appendInt:0 OfLength:1 ToData:mprData BigEndian:NO];  // Rsvd
        [Util appendInt:DG_DATA_HEADER_PAYLOAD_TYPE_MISSING_PACKETS_REQUEST OfLength:1 ToData:mprData BigEndian:NO];  // Payload Type
        
        // Num Missing Packets
        [Util appendInt:currNumMissingPacketsToSend OfLength:MPRPL_NUM_MISSING_PACKETS_LENGTH ToData:mprData BigEndian:NO];
        
        // Rsvd0
        [Util appendInt:0 OfLength:MPRPL_RSVD0_LENGTH ToData:mprData BigEndian:NO];
        
        // Port
        [Util appendInt:port OfLength:MPRPL_PORT_LENGTH ToData:mprData BigEndian:NO];
        
        // Missing Packets' SeqId's
        for (int i = 0; i < currNumMissingPacketsToSend; i++) {
            [Util appendInt:((PcmAudioDataPayload*)missingPayloads[i]).seqId.intValue OfLength:MPRPL_PACKET_SEQID_LENGTH ToData:mprData BigEndian:NO];
        }
        
        // Now, send the MPR packet to the Server
        [infoSocket sendData:mprData toHost:serverHostIp port:INFO_PORT_NUMBER withTimeout:-1 tag:0];
        
        remainingMissingPacketsToSend -= currNumMissingPacketsToSend;
    }
}

-(void)sendChatMsgToServer:(NSString*)msg {
    NSMutableData *cmData = [[NSMutableData alloc] init];
    
    // "ToWF" Header
    [Util appendInt:0x546F5746 OfLength:4 ToData:cmData BigEndian:YES]; // "ToWF"
    [Util appendInt:0 OfLength:1 ToData:cmData BigEndian:NO];  // Rsvd
    [Util appendInt:DG_DATA_HEADER_PAYLOAD_TYPE_CHAT_MSG OfLength:1 ToData:cmData BigEndian:NO];  // Payload Type
    
    // Message
    [Util appendNullTermString:msg ToData:cmData MaxLength:UDP_DATA_PAYLOAD_SIZE PadWith0s:NO];
    
    // Now, send the packet to the Server
    [infoSocket sendData:cmData toHost:serverHostIp port:INFO_PORT_NUMBER withTimeout:-1 tag:0];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"webView:didFailLoadWithError: %@", error);
}

- (void)webViewDidFinishLoad:(UIWebView *)sender {
    NSString *scrollToBottom = @"window.scrollTo(document.body.scrollWidth, document.body.scrollHeight);";
    [sender stringByEvaluatingJavaScriptFromString:scrollToBottom];
}

- (void)logError:(NSString *)msg {
    NSString *prefix = @"<font color=\"#B40404\">";
    NSString *suffix = @"</font><br/>";
    
    [log appendFormat:@"%@%@%@\n", prefix, msg, suffix];
    
    NSString *html = [NSString stringWithFormat:@"<html><body>\n%@\n</body></html>", log];
    [_webView loadHTMLString:html baseURL:nil];
}

- (void)logInfo:(NSString *)msg {
    NSString *prefix = @"<font color=\"#6A0888\">";
    NSString *suffix = @"</font><br/>";
    
    [log appendFormat:@"%@%@%@\n", prefix, msg, suffix];
    
    NSString *html = [NSString stringWithFormat:@"<html><body>\n%@\n</body></html>", log];
    [_webView loadHTMLString:html baseURL:nil];
}

- (void)logMessage:(NSString *)msg {
    NSString *prefix = @"<font color=\"#000000\">";
    NSString *suffix = @"</font><br/>";
    
    [log appendFormat:@"%@%@%@\n", prefix, msg, suffix];
    
    NSString *html = [NSString stringWithFormat:@"<html><body>%@</body></html>", log];
    [_webView loadHTMLString:html baseURL:nil];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)dgData
                                            fromAddress:(NSData *)address
                                            withFilterContext:(id)filterContext
{
    
    // Start a new thread to parse through the data and do whatever it needs to do. (so we free up our current thread to be ready to receive the next "didReceiveData" call
    // NOTE: Looks like this is not necessary, but will keep it here for easy debug later if need be.
    /*
    dispatch_queue_t queue;
    queue = dispatch_queue_create("com.briggs-inc.towf-receiver.HandleUdpDataQueue", NULL);
    */
    /*
    dispatch_async(handleUdpDataQueue, ^{
        //[self getResultSetFromDB:docids];
        [self handleUdpData:data fromAddress:address withFilterContext:filterContext];
    });
    */

    
    [self handleUdpData:dgData fromAddress:address withFilterContext:filterContext];
}

-(void) handleUdpData:(NSData *)dgData
          fromAddress:(NSData *)address
    withFilterContext:(id)filterContext
{
    
    // Check for "ToWF" header
    uint32_t dataHeaderInt = [Util getUInt32FromData:dgData AtOffset:DG_DATA_HEADER_ID_START BigEndian:YES];
    if (dataHeaderInt != 0x546F5746) {  // "ToWF"
        NSLog(@"Yikes! Receiving a packet from some other app! Ignoring it.");
        return;
    }
    
    receivedAPacket = YES;
    if (!isServerStreaming) {
        isServerStreaming = YES;
        self.waitingForServerLabel.hidden = YES;  // Hide the "Waiting for Server to Stream" label
        self.streamView.hidden = NO;  // Show the streamView (lang selection, "start listening" button, etc)
    }
    
    
    NSString *udpDataHost = nil;
    uint16_t udpDataPort = 0;
    [GCDAsyncUdpSocket getHost:&udpDataHost port:&udpDataPort fromAddress:address];
    serverHostIp = udpDataHost;
    
    //NSLog(@"==================================");
    
    if (isBurstMode) {
        //NSLog(@"Resetting burstModeWatchdogTimer");
        // Reset watchdog timer
        if (burstModeWatchdogTimer != nil) {
            [burstModeWatchdogTimer invalidate];
            burstModeWatchdogTimer = nil;
        }
        burstModeWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval: burstModeWatchdogTimerTimeout target:self selector:@selector(onBurstModeFinished) userInfo:nil repeats:NO];
    }
    
    // Get payloadType
    uint8_t payloadType = [Util getUInt8FromData:dgData AtOffset:DG_DATA_HEADER_PAYLOAD_TYPE_START];
    
    if (udpDataPort == INFO_PORT_NUMBER) {
        //NSLog(@"udpDataPort == INFO_PORT_NUMBER");
        
        if (payloadType == DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_FORMAT) {
            // Audio Format packet
            //NSLog(@"AUDIO FORMAT Packet");
            
            // Set afdg vars
            uint32_t afdgSampleRate = [Util getUInt32FromData:dgData AtOffset:AFDG_SAMPLE_RATE_START BigEndian:NO];
            
            // If different than before, update the current audio format to the new values
            if (afdgSampleRate != (uint32_t)afSampleRate) {
                // Update afSampleRate
                afSampleRate = (float)afdgSampleRate;
                NSLog(@"Audio Format changed! Updated to: ");
                NSLog(@" Sample Rate: %d", (uint32_t)afSampleRate);
                
                isAudioFormatValid = YES;
                // ??? Maybe later add a check to make sure this is REALLY valid ???
                
                //[self logInfo:FORMAT(@"Sample Rate: %d Hz", (int)afSampleRate)];
                
                // Set Derived Audio Format vars also
                packetRateMS = (int)(1.0 / (afSampleRate * AF_FRAME_SIZE / AUDIO_DATA_MAX_VALID_SIZE) * 1000);
                burstModeWatchdogTimerTimeout = ((packetRateMS / 1000.0) - 0.001);
                
                [self createAndStartNewAudioControllerAndSetup];
            }
        } else if (payloadType == DG_DATA_HEADER_PAYLOAD_TYPE_LANG_PORT_PAIRS) {
            NSString *serverVersion = [Util getNullTermStringFromData:dgData AtOffset:LPP_SERVER_VERSION_START WithMaxLength:LPP_SERVER_VERSION_LENGTH];
            
            uint8_t numLangPortPairs = [Util getUInt8FromData:dgData AtOffset:LPP_NUM_PAIRS_START];
            
            if (numLangPortPairs != [langPortPairs getNumPairs]) {
                // Then we better erase the whole thing and start from scratch
                [langPortPairs removeAllPairs];
            }
            
            for (int i = 0; i < numLangPortPairs; i++) {
                NSString *language = [Util getNullTermStringFromData:dgData AtOffset:LPP_LANG0_START + (i*(LPP_LANG_LENGTH+LPP_PORT_LENGTH)) WithMaxLength:LPP_LANG_LENGTH];
                uint16_t port = [Util getUInt16FromData:dgData AtOffset:LPP_PORT0_START + (i*(LPP_LANG_LENGTH+LPP_PORT_LENGTH)) BigEndian:NO];
                if (port >= 0 && port <= 65535) {
                    // Add the lang/port pair
                    [langPortPairs addPairWithLanguage:language AndPort:port];  // Note: only adds it if it doesn't exist already.
                }
            }
            //NSLog(@"Now the langPortPairs array looks like this: %@", [langPortPairs toString]);
            
            // Init the languageTF just the very first time, when it doesn't have anything in it yet.
            //NSLog(@"langTF.text: %@", self.languageTF.text);
            if (self.languageTF.text == NULL || [self.languageTF.text isEqualToString:@""]) {
                // Select the 1st language in the list to display in the Text Field
                self.languageTF.text = [langPortPairs getLanguageAtIdx:0];
                
                // Also use this opportunity to check appVersion vs serverVersion, and alert user if they're not compatible
                NSString *serverMajorVer = [serverVersion componentsSeparatedByString:@"."][0];
                NSString *appMajorVer = [appVersionStr componentsSeparatedByString:@"."][0];
                NSLog(@"serverMajorVer: %@", serverMajorVer);
                NSLog(@"appMajorVer: %@", appMajorVer);
                if (![serverMajorVer isEqualToString:appMajorVer]) {
                    NSString *todoMsg;
                    if (appMajorVer.intValue < serverMajorVer.intValue) {
                        todoMsg = @"You need to update this app to the latest version";
                    } else {
                        todoMsg = @"The Server software must be updated to the latest version";
                    }
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Versions not Compatible!"
                                                                    message:[NSString stringWithFormat:@"This App's Version (%@) and the Server's version (%@) are not compatible. The Major version (1st number) must be the same.\n\n%@", appVersionStr, serverVersion, todoMsg]
                                                                   delegate:nil
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
                    [alert show];
                }
            }
            
            [langPicker reloadAllComponents];  // So it doesn't read from it's cache (which might be outdated).
        } else if (payloadType == DG_DATA_HEADER_PAYLOAD_TYPE_ENABLE_MPRS) {
            Boolean enabled = ([Util getUInt8FromData:dgData AtOffset:ENMPRS_ENABLED_START] == 1);
            if (!enabled) {
                self.sendMissingPacketsRequestsSwitch.on = NO;
            }
            self.sendMissingPacketsRequestsSwitch.enabled = enabled;
        } else if (payloadType == DG_DATA_HEADER_PAYLOAD_TYPE_CHAT_MSG) {
            NSString *msg = [Util getNullTermStringFromData:dgData AtOffset:CHATMSG_MSG_START WithMaxLength:UDP_DATA_PAYLOAD_SIZE];
            [self logMessage:[NSString stringWithFormat:@"Server: %@", msg]];

            // Beep
            [dripSoundPlayer play];
            
        } else if (payloadType == DG_DATA_HEADER_PAYLOAD_TYPE_RLS) {
            [self sendClientListeningWithIsListening:isListening Port:streamPort];
        }
    } else {  // Not the INFO PORT NUMBER (7769), so must be an audio streaming port (7770, 7771, etc)
        
        if (!isListening) return;
        
        // Must be Audio Data packet
        //NSLog(@"AUDIO DATA packet");
        
        audioDataPort = udpDataPort;
        
        numReceivedAudioDataPackets++;
        
        receivedAnAudioPacket = YES;
        
        
        if (isAudioFormatValid) {
            
            int numSkippedPackets = 0;
            PcmAudioDataPayload *pcmAudioDataPayload = [[PcmAudioDataPayload alloc] initWithPayload:[dgData subdataWithRange:NSMakeRange(DG_DATA_HEADER_LENGTH, dgData.length-DG_DATA_HEADER_LENGTH)]];
            
            // Check if we need to reload or stop reloading the circBuffer
            int currCircBufferDataSize = [self.dgChannel getBufferDataSize];
            float currCircBufferDataSizeSecs = [self getNumAudioSecondsFromNumAudioBytes:currCircBufferDataSize / 2];  // /2 to get back to MONO
            if (currCircBufferDataSize == 0) {
                if (!isReloadingCircularBuffer) {
                    // Pause/Stop audioController
                    [self.audioController stop];
                }
                
                // Then the speaker HW ran out of audio to play. We'd better reload (refill) the circular buffer (i.e. stop playing until it's refilled with X amount of audio data)
                isReloadingCircularBuffer = YES;
            } else {
                if (isReloadingCircularBuffer == YES) {
                    if (currCircBufferDataSizeSecs >= self.desiredDelayLabel.text.floatValue) {
                        // Restart the audioController
                        isReloadingCircularBuffer = NO;
                        [self startAudioController];
                    }
                }
            }
            
            // Change playback speed if needed
            [self changePlaybackSpeedIfNeededGivenCurrCircBufferDataSizeSecs:currCircBufferDataSizeSecs];
            
            SeqId *currSeqId = pcmAudioDataPayload.seqId;
            
            // === Fill the Play Queue, based on sendMissingPacketsRequestsSwitch ===
            if ([self.sendMissingPacketsRequestsSwitch isOn]) {
            
                //NSLog(@"==================================");
                //NSLog(@"pre-payloadStorageList(%d) -> [%@]", [payloadStorageList getSize], [payloadStorageList toString]);
                
                //SeqId *currSeqId = pcmAudioDataPayload.seqId;
                
                //NSLog(@"Received Audio Packet: (0x%04x) {%@}", currSeqId.intValue, [Util getUInt8FromData:dgData AtOffset:DG_DATA_HEADER_PAYLOAD_TYPE_START] == DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA_MISSING ? @"Missing" : @"Regular");
                
                if (!firstPacketReceived) {
                    //NSLog(@"First Packet (0x%04x) JUST received (not counting any SKIPPED packets)", currSeqId.intValue);
                    firstPacketReceived = YES;
                    [self queueThisPayload:pcmAudioDataPayload];
                } else if ([currSeqId isLessThanOrEqualToSeqId:lastQueuedSeqId]) {
                    //NSLog(@"This Packet (0x%04x) has already been received & Queued to be played. Not doing anything with the packet.", currSeqId.intValue);
                } else if ([currSeqId isEqualToSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
                    //NSLog(@"This packet (0x%04x) is next in line for the Play Queue.", currSeqId.intValue);

                    if ([payloadStorageList hasMissingPayloadAtFirstElementWithThisSeqId:currSeqId]) {
                        //NSLog(@" Looks like it (0x%04x) was a 'missing packet' - GREAT, the Server sent it again! Regular or Missing: (%@). Queing it up & Removing it from missingPacketsSeqIdsList", currSeqId.intValue, [Util getUInt8FromData:dgData AtOffset:DG_DATA_HEADER_PAYLOAD_TYPE_START] == DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA_MISSING ? @"M" : @"R");
                        
                        [payloadStorageList popFirstPayload];
                        [self queueThisPayload:pcmAudioDataPayload];
                        
                        [self checkForReadyToQueuePacketsInStorageList];  // This function also queues them up for playing if they exist.
                        
                        if ([payloadStorageList getTotalNumPayloads] == 0) {
                            isWaitingOnMissingPackets = NO;
                            //NSLog(@"NOT WAITING on Missing Packet(s) anymore!");
                        } else {
                            //NSLog(@"STILL WAITING on Missing Packet(s)!");
                        }
                    } else {
                        // Check that we're in a good state
                        if ([payloadStorageList hasMissingPayloadAtFirstElement]) {
                            //NSLog(@" !!! Don't think we should get here! This packet (0x%04x) is next in line for Play Queue, but we have a missing payload (0x%04x) at the front of the StorageList. Anything 'missing' at the front of the StorageList should be holding up audio playback.", currSeqId.intValue, [payloadStorageList getFirstPayload].seqId.intValue);
                        } else {
                            //NSLog(@" there are NO missing packets at front of StorageList. Queing it (0x%04x) up to be played.", currSeqId.intValue);
                            [self queueThisPayload:pcmAudioDataPayload];
                        }
                    }
                } else if ([currSeqId isGreaterThanSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {

                    numSkippedPackets = [currSeqId numSeqIdsExclusivelyBetweenMeAndSeqId:lastQueuedSeqId];
                    //NSLog(@"%d packet(s) between NOW (0x%04x) and LAST_QUEUED (0x%04x). Updating payloadStorageList as appropriate", numSkippedPackets, currSeqId.intValue, lastQueuedSeqId.intValue);
                    
                    if (!isBurstMode) {
                        //NSLog(@"---Burst Mode Started---");
                    }
                    isBurstMode = YES;  // In case we just got a whole "burst" of packets (i.e. received faster than the packet rate for the given sample rate)
                    
                    // === Add the "Missing Packets" if they're not already in the list ===
                    Boolean addMissingPackets = NO;
                    SeqId *currHighestMissingSeqId = [[SeqId alloc] initWithInt:currSeqId.intValue - 1];
                    if (!isWaitingOnMissingPackets) {
                        // Up to this point, we have NOT been waiting on any missing packets. This is the first, so add them to the list.
                        addMissingPackets = YES;
                        highestMissingSeqId = currHighestMissingSeqId;
                    } else {
                        // We are already waiting on 1 or more missing packets
                        if ([currHighestMissingSeqId isGreaterThanSeqId:[[SeqId alloc] initWithInt:highestMissingSeqId.intValue + 1]]) {
                            addMissingPackets = YES;
                        }
                        if ([currHighestMissingSeqId isGreaterThanSeqId:highestMissingSeqId]) {
                            highestMissingSeqId = currHighestMissingSeqId;
                        }
                    }
                    
                    if (addMissingPackets) {
                        //NSLog(@"ADDING Missing Packets Range to payloadStorageList");
                        NSMutableArray *incrMissingPayloadsArr = [[NSMutableArray alloc] init];
                        for (int i = 0; i < numSkippedPackets; i++) {
                            SeqId *missingSeqId = [[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1 + i];
                            [incrMissingPayloadsArr addObject:[[PcmAudioDataPayload alloc] initWithSeqId:missingSeqId]];
                        }
                        [payloadStorageList addIncrementingMissingPayloads:incrMissingPayloadsArr];
                    } else {
                        //NSLog(@"NOT ADDING Missing Packets Range to payloadStorageList");
                    }
                    
                    // === Add "Received" packet ===
                    [payloadStorageList addFullPayload:pcmAudioDataPayload];
                    
                    isWaitingOnMissingPackets = YES;
                }
            } else {
                // sendMissingPacketsRequestsSwitch is OFF
                //  so just send packets to play queue as they arrive. Only exception is if only 1-3 packets are skipped, queue the received packet and repeat 1-3 times 'cuz it's "pretty likely" they were truly lost & not just out of order.
                
                // Check if this is a <Regular> or <Missing> packet. We only want to care about <Regular> packets.
                if (payloadType == DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA_REGULAR) {
                    // Queue the payload
                    [self queueThisPayload:pcmAudioDataPayload];
                    lastQueuedSeqId = currSeqId;
                    
                    // If X packets were skipped, fill in that space with a copy(s) of this packet
                    //   will keep the buffer fuller, so we don't have to SLOW DOWN so much.
                    //   the audio will still "skip" but it did that before, so nothing really lost in audio quality
                    if ([currSeqId isGreaterThanSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
                        numSkippedPackets = [currSeqId numSeqIdsExclusivelyBetweenMeAndSeqId:lastQueuedSeqId];
                        if (numSkippedPackets <= 3) {
                            for (int i = 0; i < numSkippedPackets; i++) {
                                [self queueThisPayload:pcmAudioDataPayload];  // Again
                            }
                        }
                    }
                }
            }
        }
    }
}

-(void)queueThisPayload:(PcmAudioDataPayload*)payload {
    // Send data to channel's circular buffer (Queue it up to be played)
    [self.dgChannel putInCircularBufferAudioData:payload.audioData];
    
    lastQueuedSeqId = payload.seqId;
}

-(void)checkForReadyToQueuePacketsInStorageList {
    //NSLog(@" checking for ready-to-quque packets in StorageList");
    
    //while ([payloadStorageList hasFullPayloadAtFirstElementWithThisSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
    while ([payloadStorageList hasFullPayloadAtFirstElement]) {
        //NSLog(@"  Great! We've got a packet (0x%04x) in the StorageList that we can queue up now. Queueing it & Removing from the StorageList.", lastQueuedSeqId.intValue + 1);
        [self queueThisPayload:[payloadStorageList popFirstPayload]];
    }
}

-(void)changePlaybackSpeedIfNeededGivenCurrCircBufferDataSizeSecs:(float)currCircBufferDataSizeSecs {
    //NSLog(@"changePlaybackSpeedIfNeeded() currCircBuffDataSizeSecs: %f, desiredDelayLabel: %f", currCircBufferDataSizeSecs, self.desiredDelayLabel.text.floatValue);
    if (currCircBufferDataSizeSecs > self.desiredDelayLabel.text.floatValue + (self.desiredDelayLabel.text.floatValue/2.0)) {
        if (!playFaster) {
            NSLog(@"Time to play FASTER.");
            playFaster = YES;
            [self makeAudioPlayFastSpeed];
        }
    } else if (currCircBufferDataSizeSecs < self.desiredDelayLabel.text.floatValue - (self.desiredDelayLabel.text.floatValue/2.0)) {
        if (!playSlower) {
            NSLog(@"Time to play SLOWER.");
            playSlower = YES;
            [self makeAudioPlaySlowSpeed];
        }
    } else {
        if (playFaster) {
            if (currCircBufferDataSizeSecs < self.desiredDelayLabel.text.floatValue) {
                NSLog(@"Time to play NORMAL speed (after playing faster).");
                [self makeAudioPlayNormalSpeed];
                playFaster = NO;
                playSlower = NO;
            }
        } else if (playSlower) {
            if (currCircBufferDataSizeSecs > self.desiredDelayLabel.text.floatValue) {
                NSLog(@"Time to play NORMAL speed (after playing slower).");
                [self makeAudioPlayNormalSpeed];
                playFaster = NO;
                playSlower = NO;
            }
        }
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    // When device is LOCKED (screen turned OFF), then when turned back on, and app entered, infoSocket "breaks" - udpSocket:didReceiveData: delegate never gets called again. But this function is called, with error.code == 57 (Socket is not connected). At least on my iPhone 3GS (iOS 6) and iPhone6 (iOS 8) this happens. Once in a while the error.code is 4 (Socket closed).
    // Tried adding to onAppWillEnterForeground: (but similar problems: 'sometimes' the socket says it's closed sometimes not, sometimes port == 0 sometimes port == random number.)

    NSString *whichSock = [sock isEqual:udpSocket] ? @"udpSocket" : @"infoSocket";
    NSLog(@"***udpSocketDidCLOSE! Sock: %@, Error: %@", whichSock, error);
    NSLog(@" sockets current port: %d", [sock localPort]);

    // If infoSocket CLOSED with error, try to recover.
    if ([sock isEqual:infoSocket] && error != nil) {
        if ([sock localPort] != 0) {
            NSLog(@" socket has NON-ZERO (and not 7769) port #. Weird state. Let's try closing the socket yet AGAIN.");
            [sock close];  // Rest of the code in the function will execute, then udpSocketDidClose: will be called again because of this 'close' call (with nil error) for infoSocket connected to port 7769. So we just need to check that local port is not 7769 so we don't close the one we just got working!
        }
        
        NSLog(@"Trying (AGAIN) to connect infoSocket...");
        NSError *error = nil;
        if (![infoSocket bindToPort:INFO_PORT_NUMBER error:&error]) {
            [self logError:FORMAT(@"Error (AGAIN) binding to port for infoSocket: %@", error)];
            NSLog(@"Error (AGAIN) binding to port for infoSocket: %@", error);
            //return;  // Don't "return" just in case beginReceiving will still work... (doubtful, but shouldn't hurt to try)
        }
        if (![infoSocket beginReceiving:&error]) {
            [infoSocket close];
            [self logError:FORMAT(@"Error (AGAIN) beginReceiving for infoSocket: %@", error)];
            NSLog(@"Error (AGAIN) beginReceiving for infoSocket: %@", error);
            return;
        }
        NSLog(@"Listening (AGAIN) for INFO on port: %hu", [infoSocket localPort]);
    }
}

-(float) getNumAudioSecondsFromNumAudioBytes:(uint32_t)numBytes {
    return numBytes / afSampleRate / AF_SAMPLE_SIZE_IN_BYTES / AF_CHANNELS;
}

-(uint32_t) getNumAudioBytesFromNumAudioSeconds:(float)audioSeconds {
    return (uint32_t)(audioSeconds * afSampleRate * AF_SAMPLE_SIZE_IN_BYTES * AF_CHANNELS);
}

-(void) createAndStartNewAudioControllerAndSetup {
    NSLog(@"createAndStartNewAudioControllerAndSetup()");
    
    // Kill existing one, if exists
    if (self.audioController != nil) {
        NSLog(@"Existing audioController exists. Stopping it, before replacing it.");
        [self.audioController stop];
        
        // Also flush our datagram channel's circ buffer
        [self.dgChannel flushBuffer];
        
        // ????? Anything else ?????
    }
    
    if (isAudioFormatValid) {
        // Create an audio description based on our Audio Format
        AudioStreamBasicDescription audioDescription;
        memset(&audioDescription, 0, sizeof(audioDescription));

        // Note: see documentation for "AudioStreamBasicDescription" (Core Audio Data Types Reference)
        audioDescription.mFormatID          = kAudioFormatLinearPCM;
        audioDescription.mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;  // Note: setting up as "non-interleaved" makes copying mono data into the 2 stereo buffers much faster.
        audioDescription.mChannelsPerFrame  = 2;
        audioDescription.mBytesPerPacket    = AF_SAMPLE_SIZE_IN_BYTES;
        audioDescription.mFramesPerPacket   = 1;
        audioDescription.mBytesPerFrame     = AF_SAMPLE_SIZE_IN_BYTES;
        audioDescription.mBitsPerChannel    = AF_SAMPLE_SIZE_IN_BITS;
        audioDescription.mSampleRate        = afSampleRate;
        
        // Create Audio Controller
        self.audioController = [[AEAudioController alloc]
                                initWithAudioDescription:audioDescription
                                inputEnabled:NO];
        
        // Start Audio Controller
        [self startAudioController];
        
        // Add our datagram channel to the new audio controller
        [self.dgChannel flushBuffer];  // Make sure our buffer's empty
        [_audioController addChannels:[NSArray arrayWithObject:_dgChannel]];
        
        // Setup the timePitchFilters... (to increase & decrese playback speed when needed) - [seems we have to do this here (instead of viewDidLoad) because needs valid instance of _audioController]
        NSError *error = nil;
        
        // Fast Filter
        self.timePitchFastFilter = [[AEAudioUnitFilter alloc] initWithComponentDescription:AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_FormatConverter, kAudioUnitSubType_NewTimePitch) audioController:_audioController error:&error];
        if (error != nil) {
            NSLog(@"Error initing timePitchFastFilter: %@", error);
        }
        
        // Slow Filter
        self.timePitchSlowFilter = [[AEAudioUnitFilter alloc] initWithComponentDescription:AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_FormatConverter, kAudioUnitSubType_NewTimePitch) audioController:_audioController error:&error];
        if (error != nil) {
            NSLog(@"Error initing timePitchSlowFilter: %@", error);
        }
        
        OSStatus osStatus;
        osStatus = AudioUnitSetParameter(self.timePitchFastFilter.audioUnit, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, FAST_PLAYBACK_SPEED, 0);
        [self checkOsStatus:osStatus];
        osStatus = AudioUnitSetParameter(self.timePitchSlowFilter.audioUnit, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, SLOW_PLAYBACK_SPEED, 0);
        [self checkOsStatus:osStatus];
        
    } else {
        NSLog(@"Valid Audio Format not received yet. Not creating a new audio controller.");
    }
}

-(void) startAudioController {
    NSError *error = NULL;
    BOOL result = [self.audioController start:&error];
    if ( !result ) {
        // Report error
        NSLog(@"ERROR!: Audio Controller NOT started! Error: %@", error);
    }
}

-(void) checkOsStatus:(OSStatus)osStatus {
    if ( (osStatus) != noErr ) {
        NSLog(@"OSStatus Error: %ld -> %s:%d", (long)(osStatus), __FILE__, __LINE__);
        [self logError:FORMAT(@"OSStatus Error: %ld -> %s:%d", (long)(osStatus), __FILE__, __LINE__)];
    }
}

-(void) makeAudioPlayFastSpeed {
    NSLog(@"makeAudioPlayFastSpeed()");
    if (isListening) {
        [self.lblPlaybackSpeed setText:[NSString stringWithFormat:@"%1.1fx", FAST_PLAYBACK_SPEED]];
        [self.lblPlaybackSpeed setTextColor:colorBlue];
        
        // Remove timePitch filters from our channel (if there's any)
        [_audioController removeFilter:self.timePitchFastFilter fromChannel:self.dgChannel];
        [_audioController removeFilter:self.timePitchSlowFilter fromChannel:self.dgChannel];
        
        // Add timePitch filter
        [_audioController addFilter:self.timePitchFastFilter toChannel:self.dgChannel];
    }
}

-(void) makeAudioPlayNormalSpeed {
    NSLog(@"makeAudioPlayNormalSpeed()");
    [self.lblPlaybackSpeed setText:@"1x"];
    [self.lblPlaybackSpeed setTextColor:colorGreen];
    
    // Remove timePitch filters from our channel (if there's any)
    [_audioController removeFilter:self.timePitchFastFilter fromChannel:self.dgChannel];
    [_audioController removeFilter:self.timePitchSlowFilter fromChannel:self.dgChannel];
}

-(void) makeAudioPlaySlowSpeed {
    NSLog(@"makeAudioPlaySlowSpeed()");
    if (isListening) {
        [self.lblPlaybackSpeed setText:[NSString stringWithFormat:@"%1.1fx", SLOW_PLAYBACK_SPEED]];
        [self.lblPlaybackSpeed setTextColor:colorYellow];
        
        // Remove timePitch filters from our channel (if there's any)
        [_audioController removeFilter:self.timePitchFastFilter fromChannel:self.dgChannel];
        [_audioController removeFilter:self.timePitchSlowFilter fromChannel:self.dgChannel];

        // Add timePitch filter
        [_audioController addFilter:self.timePitchSlowFilter toChannel:self.dgChannel];
    }
}

-(void)checkWifiSsidChange {
    //NSLog(@"---checkWifiSsidChange");
    // If changed, update wifiConnection label
    NSDictionary *ssidInfo = [self fetchSSIDInfo];
    NSString *currSSID = ssidInfo[@"SSID"];
    //NSLog(@"prev: %@", prevSSID);
    //NSLog(@"curr: %@", currSSID);
    if (![currSSID isEqualToString:prevSSID]) {
        [self setWifiConnectionLabel: currSSID];
        prevSSID = currSSID;
    }
}

- (NSDictionary *)fetchSSIDInfo {
    // Returns first non-empty SSID network info dictionary.
    // see CNCopyCurrentNetworkInfo
    
    NSArray *interfaceNames = CFBridgingRelease(CNCopySupportedInterfaces());
    //NSLog(@"%s: Supported interfaces: %@", __func__, interfaceNames);
    
    NSDictionary *SSIDInfo;
    for (NSString *interfaceName in interfaceNames) {
        SSIDInfo = CFBridgingRelease(
                                     CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));
        //NSLog(@"%s: %@ => %@", __func__, interfaceName, SSIDInfo);
        
        BOOL isNotEmpty = (SSIDInfo.count > 0);
        if (isNotEmpty) {
            break;
        }
    }
    return SSIDInfo;
}

-(void)setWifiConnectionLabel:(NSString*)str {
    if (str == nil || [str isEqualToString:@""]) {
        if (TARGET_IPHONE_SIMULATOR) {
            [self.wifiConnection setText:@"Tercume"];  // Just to make it look nice for screenshots
        } else {
            [self.wifiConnection setText:@"<None>"];
        }
    } else {
        [self.wifiConnection setText:str];
    }
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [langPortPairs getNumPairs];
}

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return  1;
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    //NSLog(@"pickerRow: %d, langAtThisIdx: %@, langPortPair: %@", (int)row, [langPortPairs getLanguageAtIdx:(int)row], [langPortPairs toString]);

    return [langPortPairs getLanguageAtIdx:(int)row];
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.languageTF.text = [langPortPairs getLanguageAtIdx:(int)row];
    [self.languageTF resignFirstResponder];
}

-(void)onAppWillEnterForeground {
    //NSLog(@"--onAppWillEnterForeground function");
    // Fill in Wi-Fi Connection Label
    NSDictionary *ssidInfo = [self fetchSSIDInfo];
    [self setWifiConnectionLabel:ssidInfo[@"SSID"]];
}

-(void)checkServerStoppedStreaming {
    //NSLog(@"checkServerStoppedStreaming");
    if (!receivedAPacket) {
        if (isServerStreaming) {
            isServerStreaming = NO;
            self.waitingForServerLabel.hidden = NO;  // Show the "Waiting for Server to Stream" label
            self.streamView.hidden = YES;  // Hide the streamView (lang selection, "start listening" button, etc)
        
            // We better "click" Stop Listening too, in case user was listening at the time.
            [self onStopListening];
        }
    }
    receivedAPacket = NO;
}

-(void)checkReceivingAudio {
    //NSLog(@"checkReceivingAudio");
    if (!receivedAnAudioPacket) {
        if (isReceivingAudio) {
            isReceivingAudio = NO;
            NSLog(@"Not receiving audio...");
            [self.lblReceivingAudio setTextColor:colorVeryLightGray];
        }
    } else {
        if (!isReceivingAudio) {
            isReceivingAudio = YES;
            NSLog(@"...Receiving audio again");
            [self.lblReceivingAudio setTextColor:colorGreen];
        }
    }
    receivedAnAudioPacket = NO;
}

-(void)onBurstModeFinished {
    //NSLog(@"onBurstModeFinished()");
    //NSLog(@"---Burst Mode Finished---");
    isBurstMode = NO;
    
    // Send Missing Packets (if any), though we must limit our request so that total paylostStorageList size (in secs) doesn't exceed "desiredDelay".
    //      If payloadStorageList is too big, we must cut it down to size here, then request whatever missingPayloads are left.
    if ([payloadStorageList getMissingPayloads].count > 0) {
        
        float payloadStorageListSizeSecs = [self getNumAudioSecondsFromNumAudioBytes:[payloadStorageList getTotalNumPayloads]*AUDIO_DATA_MAX_VALID_SIZE];
        
        //NSLog(@"============================");
        //NSLog(@"payloadStorageList.totalNumPayloads: %d", [payloadStorageList getTotalNumPayloads]);
        //NSLog(@"payloadStorageList.numMissingPayloads: %d", [payloadStorageList getNumMissingPayloads]);
        //NSLog(@"payloadStorageList1: %@", [payloadStorageList getAllPayloadsSeqIdsAsHexString]);
        //NSLog(@"audioDataMaxValidSize: %d", audioDataMaxValidSize);
        //NSLog(@"payloadStorageListSizeSecs: %f", payloadStorageListSizeSecs);
        //NSLog(@"self.desiredDelaySlider.value: %f", self.desiredDelaySlider.value);
        
        if (payloadStorageListSizeSecs > self.desiredDelaySlider.value) {
            float numSecsToCut = payloadStorageListSizeSecs - self.desiredDelaySlider.value;
            //NSLog(@"numSecsToCut: %f", numSecsToCut);
            uint32_t numBytesToCut = [self getNumAudioBytesFromNumAudioSeconds:numSecsToCut];
            //NSLog(@"numBytesToCut: %d", numBytesToCut);
            uint32_t numPayloadsToCut = numBytesToCut / AUDIO_DATA_MAX_VALID_SIZE;
            //NSLog(@"numPayloadsToCut: %d", numPayloadsToCut);
            if (numPayloadsToCut > 0) {
                //NSLog(@"payloadStorageList.totalNumPayloads(Before): %d", [payloadStorageList getTotalNumPayloads]);
                //NSLog(@"payloadStorageList.numMissingPayloads(Before): %d", (int)[payloadStorageList getMissingPayloads].count);
                
                [payloadStorageList removeMissingPayloadsInFirstXPayloads:numPayloadsToCut];  // Leave any full payloads 'cuz we already got them and we'll instantly queue them up anyhow with our coming up call to checkForReadyToQueuePacketsInStorageList.
                
                // Update lastQueuedSeqId, even though it hasn't actually been queued. Need to do this so when we compare the next received packet to lastQueuedSeqId, the right path for the packet will be chosen.
                lastQueuedSeqId = [[SeqId alloc] initWithInt:((PcmAudioDataPayload*)[payloadStorageList getFirstPayload]).seqId.intValue - 1];
                
                //NSLog(@"payloadStorageList.totalNumPayloads(After): %d", [payloadStorageList getTotalNumPayloads]);
                //NSLog(@"payloadStorageList.numMissingPayloads(After): %d", (int)[payloadStorageList getMissingPayloads].count);
                //NSLog(@"payloadStorageList2: %@", [payloadStorageList getAllPayloadsSeqIdsAsHexString]);
                
                [self checkForReadyToQueuePacketsInStorageList];
                
                //NSLog(@"payloadStorageList.totalNumPayloads(After check for Ready-to-Queue): %d", [payloadStorageList getTotalNumPayloads]);
                //NSLog(@"payloadStorageList3: %@", [payloadStorageList getAllPayloadsSeqIdsAsHexString]);
            }
        }
        
        NSArray *missingPayloads = [payloadStorageList getMissingPayloads];
        [self sendMissingPacketsRequestWithPort:audioDataPort AndMissingPayloads:missingPayloads];
        NSLog(@"Sending **MISSING PACKETS REQUEST** with port:%d, and ALL missing payloads(%d): %@", audioDataPort, (int)missingPayloads.count, [payloadStorageList getMissingPayloadsSeqIdsAsHexString]);
        
        
        
    } else {
        //NSLog(@"No Missing Packets to Send. Ok.");
    }
}

- (IBAction)desiredDelaySliderValueChanged:(id)sender {
    self.desiredDelayLabel.text = [NSString stringWithFormat:@"%1.2f", self.desiredDelaySlider.value];
}

NSString* deviceName() {
    NSDictionary *deviceNameDict = @{
        @"i386" : @"32-bit Simulator",
        @"x86_64" : @"64-bit Simulator",
        @"iPod1,1" : @"iPod Touch",
        @"iPod2,1" : @"iPod Touch 2nd Gen",
        @"iPod3,1" : @"iPod Touch 3rd Gen",
        @"iPod4,1" : @"iPod Touch 4th Gen",
        @"iPhone1,1" : @"iPhone",
        @"iPhone1,2" : @"iPhone 3G",
        @"iPhone2,1" : @"iPhone 3GS",
        @"iPad1,1" : @"iPad",
        @"iPad2,1" : @"iPad 2",
        @"iPad3,1" : @"iPad 3rd Gen",
        @"iPhone3,1" : @"iPhone 4 (GSM)",
        @"iPhone3,3" : @"iPhone 4 (CDMA/Verizon/Sprint)",
        @"iPhone4,1" : @"iPhone 4S",
        @"iPhone5,1" : @"iPhone 5 (model A1428, AT&T/Canada)",
        @"iPhone5,2" : @"iPhone 5 (model A1429, everything else)",
        @"iPad3,4" : @"iPad 4th Gen",
        @"iPad2,5" : @"iPad Mini",
        @"iPhone5,3" : @"iPhone 5c (model A1456, A1532 | GSM)",
        @"iPhone5,4" : @"iPhone 5c (model A1507, A1516, A1526 (China), A1529 | Global)",
        @"iPhone6,1" : @"iPhone 5s (model A1433, A1533 | GSM)",
        @"iPhone6,2" : @"iPhone 5s (model A1457, A1518, A1528 (China), A1530 | Global)",
        @"iPad4,1" : @"iPad 5th Gen (iPad Air) - Wifi",
        @"iPad4,2" : @"iPad 5th Gen (iPad Air) - Cellular",
        @"iPad4,4" : @"iPad Mini 2nd Gen - Wifi",
        @"iPad4,5" : @"iPad Mini 2nd Gen - Cellular",
        @"iPhone7,1" : @"iPhone 6 Plus",
        @"iPhone7,2" : @"iPhone 6",
    };
    
    struct utsname systemInfo;
    uname(&systemInfo);
    
    NSString* rawDeviceName = [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];

    for (id key in deviceNameDict) {
        if ([rawDeviceName isEqualToString:key]) {
            return deviceNameDict[key];  // Friendly name
        }
    }
    
    return rawDeviceName;  // Raw name
}

-(NSString*)getMissingPacketsSeqIdsAsHexString:(NSMutableArray*)mpSeqIdsList {
    NSMutableString *s = [[NSMutableString alloc] init];
    for (int i = 0; i < mpSeqIdsList.count; i++) {
        [s appendString:[NSString stringWithFormat:@"0x%04x, ", ((SeqId*)mpSeqIdsList[i]).intValue]];
    }
    
    return s;
}

-(NSString*)getAllSeqIdsInPcmAudioDataPayloadStorageListAsHexString:(NSMutableArray*)pcmADPStorageList {
    NSMutableString *s = [[NSMutableString alloc] init];
    for (int i = 0; i < pcmADPStorageList.count; i++) {
        [s appendString:[NSString stringWithFormat:@"0x%04x, ", ((PcmAudioDataPayload*)pcmADPStorageList[i]).seqId.intValue]];
    }
    
    return s;
}

-(void) processOutgoingChatMsg {
    [self.chatMsgTF resignFirstResponder];
    
    NSString *msg = self.chatMsgTF.text;

    if (![msg isEqualToString:@""]) {
        self.chatMsgTF.text = @"";  // Clear text field
        [self logMessage:[NSString stringWithFormat:@"Me: %@", msg]];  // Show msg in the web-view
        [self sendChatMsgToServer:msg]; // Send msg to Server
        // Beep
        [dripSoundPlayer play];
    }
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.chatMsgTF) {
        //[textField resignFirstResponder];
        [self processOutgoingChatMsg];
        return NO;
    }
    
    return NO;
}

@end
