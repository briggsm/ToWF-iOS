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
#import <sys/utsname.h>
@import SystemConfiguration.CaptiveNetwork;


#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

/*
#define TICK NSDate *startTime = [NSDate date]
#define TOCK NSLog(@"%s Time: %fus", __func__, [startTime timeIntervalSinceNow] * -1000000.0)
#define TOCK1 NSLog(@"%s Time1: %fus", __func__, [startTime timeIntervalSinceNow] * -1000000.0)
#define TOCK2 NSLog(@"%s Time2: %fus", __func__, [startTime timeIntervalSinceNow] * -1000000.0)
#define TOCK3 NSLog(@"%s Time3: %fus", __func__, [startTime timeIntervalSinceNow] * -1000000.0)
#define TOCK4 NSLog(@"%s Time4: %fus", __func__, [startTime timeIntervalSinceNow] * -1000000.0)
*/

#define INFO_PORT_NUMBER 7769

// Broadcast
#define DG_DATA_HEADER_LENGTH 6  // Bytes

// UDP PACKET
#define UDP_PACKET_SIZE 512
#define UDP_HEADER_SIZE 8
#define IPV4_HEADER_SIZE 20
#define ETH_HEADER_SIZE 14
#define UDP_DATA_SIZE (UDP_PACKET_SIZE - UDP_HEADER_SIZE - IPV4_HEADER_SIZE - ETH_HEADER_SIZE) //512-42=470
#define UDP_PAYLOAD_SIZE (UDP_DATA_SIZE - DG_DATA_HEADER_LENGTH)  //470-6=464

// Audio Datagram Constants
#define DG_DATA_HEADER_ID_START 0  // "ToWF"
#define DG_DATA_HEADER_ID_LENGTH 4
#define DG_DATA_HEADER_CHANNEL_START 4  // Rsvd
#define DG_DATA_HEADER_CHANNEL_LENGTH 1 // Rsvd
#define DG_DATA_HEADER_PAYLOAD_TYPE_START 5
#define DG_DATA_HEADER_PAYLOAD_TYPE_LENGTH 1

// Audio Data Datagram (port 7770-777x)
#define DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_FORMAT 0
#define DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA 1
// Info Datagram (port 7769)
#define DG_DATA_HEADER_PAYLOAD_TYPE_LANG_PORT_PAIRS 2  // NOTE: Payload Types don't need to be unique across different PORTs, but I'm making them unique just to keep them a bit easier to keep track of.
#define DG_DATA_HEADER_PAYLOAD_TYPE_CLIENT_LISTENING 3
#define DG_DATA_HEADER_PAYLOAD_TYPE_MISSING_PACKETS_REQUEST 4
#define DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA_MISSING 5


// OS Constants
#define OS_OTHER 0
#define OS_IOS 1
#define OS_ANDROID 2


#define AFDG_SAMPLE_RATE_START (DG_DATA_HEADER_LENGTH + 0)
#define AFDG_SAMPLE_RATE_LENGTH 4
#define AFDG_SAMPLE_SIZE_IN_BITS_START (DG_DATA_HEADER_LENGTH + 4)
#define AFDG_SAMPLE_SIZE_IN_BITS_LENGTH 1
#define AFDG_CHANNELS_START (DG_DATA_HEADER_LENGTH + 5)
#define AFDG_CHANNELS_LENGTH 1
#define AFDG_SIGNED_START (DG_DATA_HEADER_LENGTH + 6)
#define AFDG_SIGNED_LENGTH 1
#define AFDG_BIG_ENDIAN_START (DG_DATA_HEADER_LENGTH + 7)
#define AFDG_BIG_ENDIAN_LENGTH 1

/*
// Audio Data Payload Constants
#define ADPL_HEADER_SEQ_ID_START DG_DATA_HEADER_LENGTH + 0
#define ADPL_HEADER_SEQ_ID_LENGTH 2
#define ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_START DG_DATA_HEADER_LENGTH + 2
#define ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_LENGTH 2

#define ADPL_HEADER_LENGTH ADPL_HEADER_SEQ_ID_LENGTH + ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_LENGTH
#define ADPL_AUDIO_DATA_START DG_DATA_HEADER_LENGTH + ADPL_HEADER_LENGTH
*/
#define ADPL_AUDIO_DATA_AVAILABLE_SIZE (UDP_PAYLOAD_SIZE - ADPL_HEADER_LENGTH)

// Lang/Port Pairs Constants
#define LPP_NUM_PAIRS_START (DG_DATA_HEADER_LENGTH + 0)
#define LPP_NUM_PAIRS_LENGTH 1
#define LPP_RSVD0_START (DG_DATA_HEADER_LENGTH + 1)
#define LPP_RSVD0_LENGTH 1
#define LPP_LANG0_START (DG_DATA_HEADER_LENGTH + 2)
#define LPP_LANG_LENGTH 16
#define LPP_PORT0_START (DG_DATA_HEADER_LENGTH + 18)
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
#define MPRPL_PACKET0_SEQID_LENGTH 2
//#define MPRPL_HEADER_LENGTH MPRPL_NUM_MISSING_PACKETS_LENGTH + MPRPL_RSVD0_LENGTH + MPRPL_PORT_LENGTH +
#define MPRPL_PACKETS_AVAILABLE_SIZE (UDP_DATA_SIZE - DG_DATA_HEADER_LENGTH - MPRPL_NUM_MISSING_PACKETS_LENGTH - MPRPL_RSVD0_LENGTH - MPRPL_PORT_LENGTH)


//#define UDP_AUDIO_DATA_AVAILABLE_SIZE (UDP_DATA_SIZE - DG_DATA_HEADER_LENGTH - ADPL_HEADER_LENGTH)  // 470-6-4=460
#define UDP_AUDIO_DATA_AVAILABLE_SIZE (UDP_PAYLOAD_SIZE - UDP_

#define SERVER_STREAMING_WATCHDOG_TIMER_TIMEOUT 7.0  // If we don't receive any packets from the server in this many seconds, we consider the server NOT STREAMING.

#define FAST_PLAYBACK_SPEED 1.2
#define SLOW_PLAYBACK_SPEED 0.8

#define MPR_DELAY_RESET 5  // Number(X) of Frames that we must receive, where all X Frame are NOT the first missing packet in our payloadStorageList. If mprDelayTimer reaches 0, THEN we'll send MissingPacketRequest (if any)
//#define MPR_DELAY_NUM_PACKETS_TO_REQUEST 5


struct AudioFormat {
    float sampleRate;
    uint8_t sampleSizeInBits;
    uint8_t channels;
    BOOL isSigned;
    BOOL isBigEndian;
};


@interface ViewController ()
{
    BOOL isListening;
    
    GCDAsyncUdpSocket *udpSocket;
    GCDAsyncUdpSocket *infoSocket;  // listens to "info" on port 7769 (e.g. lang/port pairs)

    NSMutableString *log;
    
    float maxAudioDelaySecs;
    
    // Audio Format
    struct AudioFormat af;
    BOOL isAudioFormatValid;

    // Audio Format - Derived
    uint8_t afSampleSizeInBytes;
    uint8_t afFrameSize;
    uint32_t audioDataMaxValidSize;
    int packetRateMS;
    NSTimeInterval burstWatchdogTimerTimeout;
    
    long numReceivedAudioDataPackets;
    long lastNumReceivedAudioDataPackets;
    //uint16_t lastAudioDataSeqId;
    //uint16_t lastQueuedSeqId;
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
    NSTimer *serverStreamingWatchdogTimer;
    BOOL isReceivingAudio;
    NSTimer *receivingAudioWatchdogTimer;
    
    BOOL isReloadingCircularBuffer;
    
    int streamPort;
    
    NSString *serverHostIp;
    uint16_t audioDataPort;
    
    dispatch_queue_t handleUdpDataQueue;
    
    //NSMutableArray *missingPacketsSeqIdsList;
    //NSMutableArray *pcmAudioDataPayloadStorageList;
    PayloadStorageList *payloadStorageList;
    
    //int mprDelayCtr;
    int mprDelayTimer;
    
    SeqId *highestMissingSeqId;
    Boolean isWaitingOnMissingPackets;

    Boolean isBurstMode;
    NSTimer *burstModeWatchdogTimer;
    
    
    

}

@property (weak, nonatomic) IBOutlet UILabel *wifiConnection;
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
@property (nonatomic, strong) AEAudioController *audioController;
@property (nonatomic, strong) DatagramChannel *dgChannel;
@property (nonatomic, strong) AEAudioUnitFilter *timePitchFastFilter;
@property (nonatomic, strong) AEAudioUnitFilter *timePitchSlowFilter;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /*
    SeqId *currSeqIdA = [[SeqId alloc] initWithInt:0x7FFF];
    SeqId *currSeqIdB = [[SeqId alloc] initWithInt:0x7FFE];
    //if (currSeqIdA == currSeqIdB) {
    if ([currSeqIdA isEqualTo:currSeqIdB]) {
        NSLog(@"A==B");
    //} else if (currSeqIdA < currSeqIdB) {
    } else if ([currSeqIdA isLessThan:currSeqIdB]) {
        NSLog(@"A<B");
    } else if ([currSeqIdA isGreaterThan:currSeqIdB]) {
        NSLog(@"A>B");
    } else {
        NSLog(@"Uh ohh!!!!!!!! A>  < == != B");
    }
    */

    // Init lots of stuff
    log = [[NSMutableString alloc] init];

    // UDP Socket
    udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    //dispatch_queue_t sq = dispatch_queue_create("com.briggs_inc.HPSocketQueue", NULL);
    //dispatch_set_target_queue(sq, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    //udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue() socketQueue:sq];
    //udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:sq];
    
    [udpSocket setIPv4Enabled:YES];
    [udpSocket setIPv6Enabled:NO];  // Must do this for broadcast packets cuz, for whatever reason, even if just 1 packet is received, udpSocket:didReceiveData:... will get called once for EACH IPv4 and IPv6!, resulting in twice as many packets getting received.
    
    // Info Socket
    infoSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [infoSocket setIPv4Enabled:YES];
    [infoSocket setIPv6Enabled:NO];
    NSError *error = nil;
    if (![infoSocket bindToPort:INFO_PORT_NUMBER error:&error]) {
        [self logError:FORMAT(@"Error binding to port for infoSocket: %@", error)];
        return;
    }
    if (![infoSocket beginReceiving:&error]) {
        [infoSocket close];
        [self logError:FORMAT(@"Error beginReceiving for infoSocket: %@", error)];
        return;
    }
    [self logInfo:FORMAT(@"Listening for INFO on port %hu", [infoSocket localPort])];
    
    
    
    maxAudioDelaySecs = 0.25;  // Default
    
    isAudioFormatValid = NO;
    playbackRate = 1.0;  // 1x speed.
    playFaster = NO;
    af.sampleRate = 0;  // An invalid sample rate

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
    if (ssidStr == NULL || [ssidStr isEqual: @""]) {
        if (TARGET_IPHONE_SIMULATOR) {
            [self.wifiConnection setText:@"Tercume"];  // Just to make it look nice for screenshots
        } else {
            [self.wifiConnection setText:@"<None>"];
        }
    } else {
        [self.wifiConnection setText:ssidInfo[@"SSID"]];
    }

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppEnteredForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    isReloadingCircularBuffer = NO;
    
    self.streamView.hidden = YES;
    self.listeningView.hidden = YES;
    
    isListening = NO;
    
    _webView.dataDetectorTypes = UIDataDetectorTypeNone;
    
    handleUdpDataQueue = dispatch_queue_create("com.briggs-inc.towf-receiver.HandleUdpDataQueue", NULL);
    
    //missingPacketsSeqIdsList = [[NSMutableArray alloc] init];
    //pcmAudioDataPayloadStorageList = [[NSMutableArray alloc] init];
    payloadStorageList = [[PayloadStorageList alloc] init];
    
    //mprDelayCtr = 0;
    mprDelayTimer = MPR_DELAY_RESET;
    
    highestMissingSeqId = [[SeqId alloc] initWithInt:0];
    isWaitingOnMissingPackets = NO;
    isBurstMode = NO;
    
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

- (void)onStopListening {
    NSLog(@"onStopListening()");
    
    // Stop Audio Controller
    [_audioController stop];
    
    // Flush circular buffer
    [self.dgChannel flushBuffer];
    
    // Stop Socket-related
    [udpSocket close];
    
    [self logInfo:@"Stopped Listening"];
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
    //[missingPacketsSeqIdsList removeAllObjects];
    //[pcmAudioDataPayloadStorageList removeAllObjects];
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
    
    [self logInfo:FORMAT(@"Started listening on port %hu", [udpSocket localPort])];
    isListening = YES;
    if (!isAudioFormatValid) {
        [self logInfo:FORMAT(@"Waiting for Audio Format packet...")];
    }
    
    
    // For Debug
    //NSLog(@"uniqueIdentifier: %@", [[UIDevice currentDevice] uniqueIdentifier]);
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
    
    // Send the server the "Client Listening" packet
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
    [Util appendNullTermString:osVer ToData:clData MaxLength:CLPL_OS_VERSION_STR_LENGTH];
    
    // HW Manufacturer
    [Util appendNullTermString:@"Apple" ToData:clData MaxLength:CLPL_HW_MANUFACTURER_STR_LENGTH];
    
    // HW Model
    [Util appendNullTermString:deviceName() ToData:clData MaxLength:CLPL_HW_MODEL_STR_LENGTH];
    
    // Users Name / Device Name
    [Util appendNullTermString:[[UIDevice currentDevice] name] ToData:clData MaxLength:CLPL_USERS_NAME_LENGTH];
    
    // Now, send the CL packet to server
    [infoSocket sendData:clData toHost:serverHostIp port:INFO_PORT_NUMBER withTimeout:-1 tag:0];
}

//-(void)sendMissingPacketsRequestWithPort:(int)port AndMissingPackets:(NSArray*)mpSeqIdsList {
-(void)sendMissingPacketsRequestWithPort:(int)port AndMissingPayloads:(NSArray*)missingPayloads {
    // Send 1 (or more, if needed) Missing Packets Request
    
    //if (mpSeqIdsList.count <= 0) {
    if (missingPayloads.count <= 0) {
        return;  // Don't send anything if we don't have missing packets
    }
    
    //int remainingMissingPacketsToSend = (int)mpSeqIdsList.count;
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
        //for (id seqId in mpSeqIdsList) {
        for (id missingPayload in missingPayloads) {
            [Util appendInt:((PcmAudioDataPayload*)missingPayload).seqId.intValue OfLength:MPRPL_PACKET0_SEQID_LENGTH ToData:mprData BigEndian:NO];
        }
        
        // Now, send the MPR packet to the Server
        [infoSocket sendData:mprData toHost:serverHostIp port:INFO_PORT_NUMBER withTimeout:-1 tag:0];
        
        remainingMissingPacketsToSend -= currNumMissingPacketsToSend;
    }
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
    
    NSString *udpDataHost = nil;
    uint16_t udpDataPort = 0;
    [GCDAsyncUdpSocket getHost:&udpDataHost port:&udpDataPort fromAddress:address];
    serverHostIp = udpDataHost;
    
    NSLog(@"==================================");
    
    if (isBurstMode) {
        NSLog(@"Resetting burstModeWatchdogTimer");
        // Reset watchdog timer
        if (burstModeWatchdogTimer != nil) {
            [burstModeWatchdogTimer invalidate];
            burstModeWatchdogTimer = nil;
        }
        burstModeWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval: burstWatchdogTimerTimeout target:self selector:@selector(onBurstModeFinished) userInfo:nil repeats:NO];
    }
    
    if (udpDataPort == INFO_PORT_NUMBER) {
        NSLog(@"udpDataPort == INFO_PORT_NUMBER");
        isServerStreaming = YES;
        self.waitingForServerLabel.hidden = YES;  // Hide the "Waiting for Server to Stream" label
        self.streamView.hidden = NO;  // Show the streamView (lang selection, "start listening" button, etc)
        
        // Set watchdog timer - if it fires, then hide streamView & show "waiting for server" message.
        if (serverStreamingWatchdogTimer != nil) {
            [serverStreamingWatchdogTimer invalidate];
            serverStreamingWatchdogTimer = nil;
        }
        serverStreamingWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval:SERVER_STREAMING_WATCHDOG_TIMER_TIMEOUT target:self selector:@selector(onServerStoppedStreaming) userInfo:nil repeats:NO];
        
        // Get payloadType
        uint8_t payloadType = [Util getUInt8FromData:dgData AtOffset:DG_DATA_HEADER_PAYLOAD_TYPE_START];
        
        // Check for lang/port pair
        if (payloadType == DG_DATA_HEADER_PAYLOAD_TYPE_LANG_PORT_PAIRS) {
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
            }
            
            [langPicker reloadAllComponents];  // So it doesn't read from it's cache (which might be outdated).
        }
    } else {  // Not the INFO PORT NUMBER (7769), so must be an audio streaming port (7770, 7771, etc)
        
        if (!isListening) return;
        
        // Look at Header to find out if we have an Audio Format packet, or a regular audio data packet
        uint8_t payloadType = [Util getUInt8FromData:dgData AtOffset:DG_DATA_HEADER_PAYLOAD_TYPE_START];
        
        if (payloadType == DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_FORMAT) {
            
            // Audio Format packet
            NSLog(@"AUDIO FORMAT Packet");
            
            // Set afdg vars
            uint32_t afdgSampleRate = [Util getUInt32FromData:dgData AtOffset:AFDG_SAMPLE_RATE_START BigEndian:NO];
            uint8_t afdgSampleSizeInBits = [Util getUInt8FromData:dgData AtOffset:AFDG_SAMPLE_SIZE_IN_BITS_START];
            uint8_t afdgChannels = [Util getUInt8FromData:dgData AtOffset:AFDG_CHANNELS_START];
            BOOL afdgIsSigned = [Util getUInt8FromData:dgData AtOffset:AFDG_SIGNED_START] == 1 ? YES : NO;
            BOOL afdgIsBigEndian = [Util getUInt8FromData:dgData AtOffset:AFDG_BIG_ENDIAN_START] == 1 ? YES : NO;
            
            // If different than before, update the current audio format to the new values
            if (afdgSampleRate != (uint32_t)af.sampleRate || afdgSampleSizeInBits != af.sampleSizeInBits || afdgChannels != af.channels || afdgIsSigned != af.isSigned || afdgIsBigEndian != af.isBigEndian) {
                // Update "af" Audio Format
                af.sampleRate = afdgSampleRate;
                af.sampleSizeInBits = afdgSampleSizeInBits;
                af.channels = afdgChannels;
                af.isSigned = afdgIsSigned;
                af.isBigEndian = afdgIsBigEndian;
                
                NSLog(@"Audio Format changed! Updated to: ");
                NSLog(@" Sample Rate: %d", (uint32_t)af.sampleRate);
                NSLog(@" Sample Size (in bits): %d", af.sampleSizeInBits);
                NSLog(@" Channels: %d", af.channels);
                NSLog(@" isSigned: %@", af.isSigned ? @"YES" : @"NO");
                NSLog(@" isBigEndian: %@", af.isBigEndian ? @"YES" : @"NO");
                
                
                isAudioFormatValid = YES;
                // ??? Maybe later add a check to make sure this is REALLY valid ???
                
                [self logInfo:FORMAT(@"Received Audio Format: %d, %d, %d, %@, %@", (int)af.sampleRate, af.sampleSizeInBits, af.channels, af.isSigned ? @"signed" : @"unsigned", af.isBigEndian ? @"bigEndian" : @"littleEndian")];
                
                // Set Derived Audio Format vars also
                afSampleSizeInBytes = af.sampleSizeInBits / 8; if (af.sampleSizeInBits % 8 != 0) { afSampleSizeInBytes++; }
                afFrameSize = afSampleSizeInBytes * af.channels;
                audioDataMaxValidSize = (ADPL_AUDIO_DATA_AVAILABLE_SIZE - (ADPL_AUDIO_DATA_AVAILABLE_SIZE % afFrameSize));
                packetRateMS = (int)(1.0 / (af.sampleRate * afFrameSize / audioDataMaxValidSize) * 1000);
                //burstWatchdogTimerTimeout = ((packetRateMS / 1000.0) - 0.0005);
                burstWatchdogTimerTimeout = ((packetRateMS / 1000.0) - 0.001);
                
                [self createAndStartNewAudioControllerAndSetup];
            }
        } else {
            // Must be Audio Data packet
            NSLog(@"AUDIO DATA packet");
            
            audioDataPort = udpDataPort;
            
            numReceivedAudioDataPackets++;
            //mprDelayCtr--;
            
            if (!isReceivingAudio) {
                NSLog(@"Receiving audio again");
                [self.lblReceivingAudio setTextColor:colorGreen];
            }
            isReceivingAudio = YES;
            if (receivingAudioWatchdogTimer != nil) {
                [receivingAudioWatchdogTimer invalidate];
                receivingAudioWatchdogTimer = nil;
            }
            receivingAudioWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(onCurrentlyNotReceivingAudio) userInfo:nil repeats:NO];  // 0.1 => 10 fps "refresh rate" // 0.2 => 5 fps "refresh rate"
            
            if (isAudioFormatValid) {
                
                int numSkippedPackets = 0;
                //Boolean queueThisPacket = NO;
                //Boolean checkForReadyToQueuePacketsInStorageList = NO;
                Boolean skipMissingPacketsRequestThisTimeThrough = NO;
                PcmAudioDataPayload *pcmAudioDataPayload = [[PcmAudioDataPayload alloc] initWithPayload:[dgData subdataWithRange:NSMakeRange(DG_DATA_HEADER_LENGTH, dgData.length-DG_DATA_HEADER_LENGTH)]];
                
                
                
                // Check if we need to reload or stop reloading the circBuffer
                int currCircBufferDataSize = [self.dgChannel getBufferDataSize];
                float currCircBufferDataSizeSecs = [self getNumAudioSecondsFromNumAudioBytes:currCircBufferDataSize];
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
                
                
                /*
                uint16_t audioDataSeqId =[Util getUInt16FromData:data AtOffset:ADPL_HEADER_SEQ_ID_START BigEndian:NO];
                //NSLog(@"audioDataSeqId: %d", audioDataSeqId);

                if (!firstPacketReceived) {
                    NSLog(@"First Packet JUST received (not counting any SKIPPED packets)");
                    firstPacketReceived = YES;
                } else if (audioDataSeqId > lastAudioDataSeqId + 1) {
                    numSkippedPackets = audioDataSeqId - lastAudioDataSeqId - 1;
                    NSLog(@"%d packets SKIPPED! LastId: 0x%04x, CurrId: 0x%04x", numSkippedPackets, lastAudioDataSeqId, audioDataSeqId);
                    
                    // Submit a Missing Packets Request
                    NSMutableArray *missingPacketsSeqIds = [[NSMutableArray alloc] init];
                    for (int i = 0; i < numSkippedPackets; i++) {
                        [missingPacketsSeqIds addObject:[NSNumber numberWithInt:lastAudioDataSeqId + 1 + i]];
                    }
                    NSLog(@" Sending missing packets request with port:%d, and missing packets: %@", port, [self getMissingPacketsSeqIdsAsHexString:missingPacketsSeqIds]);
                    [self sendMissingPacketsRequestWithPort:port AndMissingPackets:missingPacketsSeqIds];
                    
                } else if (audioDataSeqId == lastAudioDataSeqId) {
                    NSLog(@"Packet received with SAME SeqId as last packet! Shouldn't happen! Id: 0x%04x", audioDataSeqId);
                } else if (audioDataSeqId < lastAudioDataSeqId && !(audioDataSeqId == 0 && lastAudioDataSeqId == 0xFFFF)) {
                    NSLog(@"Packet received OUT OF ORDER! LastId: 0x%04x, CurrId: 0x%04x", lastAudioDataSeqId, audioDataSeqId);
                    //lastAudioDataSeqId = audioDataSeqId;
                    return; // Don't add this packet to buffer - just to prevent a bit of an audio stutter.
                }
                lastAudioDataSeqId = audioDataSeqId;
                */
                
                
                
                /*
                //NSLog(@"[%@] <- pre-missingPacketsSeqIdsList", [self getMissingPacketsSeqIdsAsHexString:missingPacketsSeqIdsList]);
                //NSLog(@"[%@] <- pre-pcmAudioDataPayloadStorageList(SeqId's)", [self getAllSeqIdsInPcmAudioDataPayloadStorageListAsHexString:pcmAudioDataPayloadStorageList]);
                NSLog(@"[%@] <- pre-payloadStorageList", [payloadStorageList toString]);
                
                //uint16_t currSeqId = [Util getUInt16FromData:dgData AtOffset:ADPL_HEADER_SEQ_ID_START BigEndian:NO];
                //uint16_t currSeqId = pcmAudioDataPayload.seqId;
                //SeqId *currSeqId = [[SeqId alloc] initWithInt:pcmAudioDataPayload.seqId];
                SeqId *currSeqId = pcmAudioDataPayload.seqId;
                
                
                if (!firstPacketReceived) {
                    NSLog(@"First Packet (0x%04x) JUST received (not counting any SKIPPED packets)", currSeqId.intValue);
                    firstPacketReceived = YES;
                    queueThisPacket = YES;
                //} else if (currSeqId <= lastQueuedSeqId) {
                } else if ([currSeqId isLessThanOrEqualToSeqId:lastQueuedSeqId]) {
                    NSLog(@"This Packet (0x%04x) has already been received & Queued to be played. Not doing anything with the packet.", currSeqId.intValue);
                    queueThisPacket = NO;
                //} else if (currSeqId == lastQueuedSeqId + 1) {
                } else if ([currSeqId isEqualToSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
                    NSLog(@"This packet (0x%04x) is next in line for the Play Queue.", currSeqId.intValue);
                    //if (missingPacketsSeqIdsList.count > 0) {
                    if ([payloadStorageList hasMissingPayloadAtFirstElement]) {
                        //NSLog(@" there are some missing packets (%d). Checking them.", (int)missingPacketsSeqIdsList.count);
                        NSLog(@" there's a missing packet at front of payloadStorageList. Checking it.");
                        //if (((NSNumber*)missingPacketsSeqIdsList[0]).intValue == currSeqId) {
                        if ([(SeqId*)missingPacketsSeqIdsList[0] isEqualToSeqId:currSeqId]) {
                            NSLog(@"  Looks like it (0x%04x) was a 'missing packet' - GREAT, the Server sent it again! Queing it up & Removing it from missingPacketsSeqIdsList", currSeqId.intValue);
                            [missingPacketsSeqIdsList removeObjectAtIndex:0];
                            queueThisPacket = YES;
                            checkForReadyToQueuePacketsInStorageList = YES;
                            skipMissingPacketsRequestThisTimeThrough = YES;  // Because there might be more missing packets coming right after this one, and we shouldn't bug the Server 10 times if 10 packets are missing.
                        } else {
                            NSLog(@"  !!! Don't think we should get here! This packet's next in line for Play Queue, missingPacketsSeqIdsList.count > 0, missingPacketsSeqIdsList[0] should ALWAYS be this packet. currSeqId: 0x%04x, missingPacketsSeqIdsList[0]: 0x%04x", currSeqId.intValue, ((SeqId*)missingPacketsSeqIdsList[0]).intValue);
                            queueThisPacket = NO;
                        }
                    } else {
                        NSLog(@" there are NO missing packets. Queing it (0x%04x) up.", currSeqId.intValue);
                        queueThisPacket = YES;
                    }
                //} else if (currSeqId > lastQueuedSeqId + 1) {
                } else if ([currSeqId isGreaterThanSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
                    //numSkippedPackets = currSeqId - lastQueuedSeqId - 1;
                    //numSkippedPackets = currSeqId.intValue - lastQueuedSeqId.intValue - 1;
                    //numSkippedPackets = [currSeqId minus:lastQueuedSeqId].intValue - 1;
                    numSkippedPackets = [currSeqId numIdsExclusivelyBetweenMeAndSeqId:lastQueuedSeqId];
                    //NSLog(@"SKIPPED %d packet(s). Updating missingPacketsSeqIdsList & dgDataStorageList as apporpriate", numSkippedPackets);
                    NSLog(@"%d packet(s) between NOW (0x%04x) and LAST_QUEUED (0x%04x). Updating missingPacketsSeqIdsList & dgDataStorageList as appropriate", numSkippedPackets, currSeqId.intValue, lastQueuedSeqId.intValue);
                    // Note: make sure to add in sort order
                    //NSLog(@" Adding missing packet(s) to missingPacketsSeqIdsList (if appropriate)");
                    for (int i = 0; i < numSkippedPackets; i++) {
                        //NSNumber *missingSeqId = [NSNumber numberWithInt:lastQueuedSeqId + i];
                        SeqId *missingSeqId = [[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1 + i];
                        
                        if (![missingPacketsSeqIdsList containsObject:missingSeqId] && ![pcmAudioDataPayloadStorageList containsObject:[[PcmAudioDataPayload alloc] initWithSeqId:missingSeqId]]) {
                            NSLog(@" Adding packet (0x%04x) to missingPacketsSeqIdsList (and sorting list)", missingSeqId.intValue);
                            // Add it to list
                            [missingPacketsSeqIdsList addObject:missingSeqId];
                            // Sort list
                            NSSortDescriptor *lowestToHighest = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES];
                            [missingPacketsSeqIdsList sortUsingDescriptors:[NSArray arrayWithObject:lowestToHighest]];
                        } else {
                            NSLog(@" missingPacketsSeqIdsList OR pcmAudioDataPayloadStorageList already contains packet (0x%04x). Not adding again.", missingSeqId.intValue);
                        }
                    }
                    
                    if (![pcmAudioDataPayloadStorageList containsObject:[[PcmAudioDataPayload alloc] initWithSeqId:currSeqId]]) {
                        NSLog(@" Adding our received packet (0x%04x) to pcmAudioDataPayloadStorageList & sorting", currSeqId.intValue);
                        [pcmAudioDataPayloadStorageList addObject:pcmAudioDataPayload];
                        //[pcmAudioDataPayloadStorageList sortedArrayUsingSelector:@selector(compare:)];
                        [pcmAudioDataPayloadStorageList sortUsingSelector:@selector(compare:)];
                    } else {
                        NSLog(@" Our received packet (0x%04x) has already been added to pcmAudioDataPayloadStorageList. Not adding again.", currSeqId.intValue);
                    }
                    
                    queueThisPacket = NO;
                }

                // Submit a Missing Packets Request (if we have any missing packets) // Note: MAYBE don't want to do this EVERY time, but it also shouldn't hurt...
                if (!skipMissingPacketsRequestThisTimeThrough && missingPacketsSeqIdsList.count > 0) {
                    NSLog(@" Sending Missing Packets Request with port:%d, and missing packets: %@", port, [self getMissingPacketsSeqIdsAsHexString:missingPacketsSeqIdsList]);
                    [self sendMissingPacketsRequestWithPort:port AndMissingPackets:missingPacketsSeqIdsList];
                }
                
                if (queueThisPacket) {
                    // Send data to channel's circular buffer (Queue it up to be played)
                    //uint16_t audioDataLength = [Util getUInt16FromData:dgData AtOffset:ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_START BigEndian:NO];
                    //uint16_t audioDataLength = pcmAudioDataPayload.audioDataAllocatedBytes;
                    
                    //NSData *audioData = [dgData subdataWithRange:NSMakeRange(ADPL_AUDIO_DATA_START, audioDataLength)];
                    //NSData *audioData = pcmAudioDataPayload.audioData;
                    
                    //[self.dgChannel putInCircularBufferAudioData:audioData];
                    [self.dgChannel putInCircularBufferAudioData:pcmAudioDataPayload.audioData];
                    lastQueuedSeqId = currSeqId;
                }
                
                if (checkForReadyToQueuePacketsInStorageList) {
                    NSLog(@"checking for ready-to-quque packets in StorageList");
                    if (pcmAudioDataPayloadStorageList.count > 0) {
                        NSLog(@" found %d in StorageList", (int)pcmAudioDataPayloadStorageList.count);
                        //if ( ((PcmAudioDataPayload*)payloadStorageList[0]).seqId == lastQueuedSeqId + 1 ) {
                        //uint16_t storedSeqId0 = [Util getUInt16FromData:(NSData*)pcmAudioDataPayloadStorageList[0] AtOffset:ADPL_HEADER_SEQ_ID_START BigEndian:NO];
                        //uint16_t storedSeqId0 = ((PcmAudioDataPayload*)pcmAudioDataPayloadStorageList[0]).seqId;
                        SeqId *storedSeqId0 = ((PcmAudioDataPayload*)pcmAudioDataPayloadStorageList[0]).seqId;
                        NSLog(@" storedSeqId0: 0x%04x", storedSeqId0.intValue);
                        //while (storedSeqId0 == lastQueuedSeqId + 1) {
                        while ([storedSeqId0 isEqualToSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
                            NSLog(@"  Great! We've got a packet (0x%04x) in the StorageList that we can queue up now. Queueing it & Removing from Storage.", storedSeqId0.intValue);
                            // Queue it up!
                            //uint16_t storedAudioDataLength = [Util getUInt16FromData:(NSData*)pcmAudioDataPayloadStorageList[0] AtOffset:ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_START BigEndian:NO];
                            //NSData *storedAudioData = [(NSData*)pcmAudioDataPayloadStorageList[0] subdataWithRange:NSMakeRange(ADPL_AUDIO_DATA_START, storedAudioDataLength)];
                            //[self.dgChannel putInCircularBufferAudioData:storedAudioData];
                            [self.dgChannel putInCircularBufferAudioData:((PcmAudioDataPayload*)pcmAudioDataPayloadStorageList[0]).audioData];
                            lastQueuedSeqId = storedSeqId0;
                            
                            // Remove from Storage
                            [pcmAudioDataPayloadStorageList removeObjectAtIndex:0];
                            
                            // Get next storedSeqId (if exists)
                            if (pcmAudioDataPayloadStorageList.count > 0) {
                                //storedSeqId0 = [Util getUInt16FromData:(NSData*)pcmAudioDataPayloadStorageList[0] AtOffset:ADPL_HEADER_SEQ_ID_START BigEndian:NO];
                                storedSeqId0 = ((PcmAudioDataPayload*)pcmAudioDataPayloadStorageList[0]).seqId;
                            } else {
                                break;  // out of while loop
                            }
                        }
                    }
                }
                */
                

                //NSLog(@"==================================");
                NSLog(@"pre-payloadStorageList(%d) -> [%@]", [payloadStorageList getSize], [payloadStorageList toString]);
                /*
                TICK;
                int ctr = 0;
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                NSLog(@"TESTing%d", ctr++);
                TOCK;
                */
                SeqId *currSeqId = pcmAudioDataPayload.seqId;
                
                NSLog(@"Received Audio Packet: (0x%04x) {%@}", currSeqId.intValue, [Util getUInt8FromData:dgData AtOffset:DG_DATA_HEADER_PAYLOAD_TYPE_START] == DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA_MISSING ? @"Missing" : @"Regular");
                
                mprDelayTimer--;
                if (mprDelayTimer < 0) { mprDelayTimer = 0; }
                TICK;
                if (!firstPacketReceived) {
                    NSLog(@"First Packet (0x%04x) JUST received (not counting any SKIPPED packets)", currSeqId.intValue);
                    firstPacketReceived = YES;
                    //queueThisPacket = YES;
                    [self queueThisPayload:pcmAudioDataPayload];
                } else if ([currSeqId isLessThanOrEqualToSeqId:lastQueuedSeqId]) {
                    NSLog(@"This Packet (0x%04x) has already been received & Queued to be played. Not doing anything with the packet.", currSeqId.intValue);
                    //queueThisPacket = NO;
                } else if ([currSeqId isEqualToSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
                    NSLog(@"This packet (0x%04x) is next in line for the Play Queue.", currSeqId.intValue);

                    if ([payloadStorageList hasMissingPayloadAtFirstElementWithThisSeqId:currSeqId]) {
                        NSLog(@" Looks like it (0x%04x) was a 'missing packet' - GREAT, the Server sent it again! Regular or Missing: (%@). Queing it up & Removing it from missingPacketsSeqIdsList", currSeqId.intValue, [Util getUInt8FromData:dgData AtOffset:DG_DATA_HEADER_PAYLOAD_TYPE_START] == DG_DATA_HEADER_PAYLOAD_TYPE_PCM_AUDIO_DATA_MISSING ? @"M" : @"R");
                        
                        //isWaitingOnMissingPacket = NO;
                        mprDelayTimer = MPR_DELAY_RESET;
                        
                        [payloadStorageList popFirstPayload];
                        //queueThisPacket = YES;
                        [self queueThisPayload:pcmAudioDataPayload];
                        
                        //checkForReadyToQueuePacketsInStorageList = YES;
                        [self checkForReadyToQueuePacketsInStorageList];  // This function also queues them up for playing if they exist.
                        
                        if ([payloadStorageList getSize] == 0) {
                            isWaitingOnMissingPackets = NO;
                            NSLog(@"NOT WAITING on Missing Packet(s) anymore!");
                        } else {
                            NSLog(@"STILL WAITING on Missing Packet(s)!");
                        }
                        
                        skipMissingPacketsRequestThisTimeThrough = YES;  // Because there might be more missing packets coming right after this one, and we shouldn't bug the Server 10 times if 10 packets are missing.
                    } else {
                        // Check that we're in a good state
                        if ([payloadStorageList hasMissingPayloadAtFirstElement]) {
                            NSLog(@" !!! Don't think we should get here! This packet (0x%04x) is next in line for Play Queue, but we have a missing payload (0x%04x) at the front of the StorageList. Anything 'missing' at the front of the StorageList should be holding up audio playback.", currSeqId.intValue, [payloadStorageList getFirstPayload].seqId.intValue);
                        } else {
                            NSLog(@" there are NO missing packets at front of StorageList. Queing it (0x%04x) up to be played.", currSeqId.intValue);
                            [self queueThisPayload:pcmAudioDataPayload];
                        }
                    }
                    TOCK2;
                    
                    /*
                    if ([payloadStorageList hasMissingPayloadAtFirstElement]) {
                        //NSLog(@" there are some missing packets (%d). Checking them.", (int)missingPacketsSeqIdsList.count);
                        NSLog(@" there's a missing packet at front of payloadStorageList. Checking it.");
                        //if (((NSNumber*)missingPacketsSeqIdsList[0]).intValue == currSeqId) {
                        if ([(SeqId*)missingPacketsSeqIdsList[0] isEqualToSeqId:currSeqId]) {
                            NSLog(@"  Looks like it (0x%04x) was a 'missing packet' - GREAT, the Server sent it again! Queing it up & Removing it from missingPacketsSeqIdsList", currSeqId.intValue);
                            [missingPacketsSeqIdsList removeObjectAtIndex:0];
                            queueThisPacket = YES;
                            checkForReadyToQueuePacketsInStorageList = YES;
                            skipMissingPacketsRequestThisTimeThrough = YES;  // Because there might be more missing packets coming right after this one, and we shouldn't bug the Server 10 times if 10 packets are missing.
                        } else {
                            NSLog(@"  !!! Don't think we should get here! This packet's next in line for Play Queue, missingPacketsSeqIdsList.count > 0, missingPacketsSeqIdsList[0] should ALWAYS be this packet. currSeqId: 0x%04x, missingPacketsSeqIdsList[0]: 0x%04x", currSeqId.intValue, ((SeqId*)missingPacketsSeqIdsList[0]).intValue);
                            queueThisPacket = NO;
                        }
                    } else {
                        NSLog(@" there are NO missing packets. Queing it (0x%04x) up.", currSeqId.intValue);
                        queueThisPacket = YES;
                    }
                    */
                } else if ([currSeqId isGreaterThanSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {

                    numSkippedPackets = [currSeqId numSeqIdsExclusivelyBetweenMeAndSeqId:lastQueuedSeqId];
                    NSLog(@"%d packet(s) between NOW (0x%04x) and LAST_QUEUED (0x%04x). Updating payloadStorageList as appropriate", numSkippedPackets, currSeqId.intValue, lastQueuedSeqId.intValue);
                    
                    if (!isBurstMode) {
                        NSLog(@"---Burst Mode Started---");
                    }
                    isBurstMode = YES;
                    
                    
                    Boolean addMissingPackets = NO;
                    if (!isWaitingOnMissingPackets) {
                        // Up to this point, we have NOT been waiting on any missing packets
                        addMissingPackets = YES;
                        
                        highestMissingSeqId = [[SeqId alloc] initWithInt:currSeqId.intValue - 1];
                        //isWaitingOnMissingPacket = YES;
                    } else {
                        // We are already waiting on 1 or more missing packets
                        SeqId *currHighestMissingSeqId = [[SeqId alloc] initWithInt:currSeqId.intValue - 1];
                        if ([currHighestMissingSeqId isGreaterThanSeqId:[[SeqId alloc] initWithInt:highestMissingSeqId.intValue + 1]]) {
                            addMissingPackets = YES;
                        }
                        if ([currHighestMissingSeqId isGreaterThanSeqId:highestMissingSeqId]) {
                            highestMissingSeqId = currHighestMissingSeqId;
                        }
                    }
                    
                    //isWaitingOnMissingPacket = YES;
                    
                    if (addMissingPackets) {
                        NSLog(@"ADDING Missing Packets Range to payloadStorageList");
                        NSMutableArray *missingPayloadsArr = [[NSMutableArray alloc] init];
                        for (int i = 0; i < numSkippedPackets; i++) {
                            SeqId *missingSeqId = [[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1 + i];
                            [missingPayloadsArr addObject:[[PcmAudioDataPayload alloc] initWithSeqId:missingSeqId]];
                            
                            /*
                             if (![missingPacketsSeqIdsList containsObject:missingSeqId] && ![pcmAudioDataPayloadStorageList containsObject:[[PcmAudioDataPayload alloc] initWithSeqId:missingSeqId]]) {
                             NSLog(@" Adding packet (0x%04x) to missingPacketsSeqIdsList (and sorting list)", missingSeqId.intValue);
                             // Add it to list
                             [missingPacketsSeqIdsList addObject:missingSeqId];
                             // Sort list
                             NSSortDescriptor *lowestToHighest = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES];
                             [missingPacketsSeqIdsList sortUsingDescriptors:[NSArray arrayWithObject:lowestToHighest]];
                             } else {
                             NSLog(@" missingPacketsSeqIdsList OR pcmAudioDataPayloadStorageList already contains packet (0x%04x). Not adding again.", missingSeqId.intValue);
                             }
                             */
                            //[payloadStorageList addMissingPayload:[[PcmAudioDataPayload alloc] initWithSeqId:missingSeqId]];
                        }
                        [payloadStorageList addIncrementingMissingPayloads:missingPayloadsArr];
                    } else {
                        NSLog(@"NOT ADDING Missing Packets Range to payloadStorageList");
                    }
                    
                    
                    // Add received packet
                    /*
                    if (![pcmAudioDataPayloadStorageList containsObject:[[PcmAudioDataPayload alloc] initWithSeqId:currSeqId]]) {
                        NSLog(@" Adding our received packet (0x%04x) to pcmAudioDataPayloadStorageList & sorting", currSeqId.intValue);
                        [pcmAudioDataPayloadStorageList addObject:pcmAudioDataPayload];
                        [pcmAudioDataPayloadStorageList sortUsingSelector:@selector(compare:)];
                    } else {
                        NSLog(@" Our received packet (0x%04x) has already been added to pcmAudioDataPayloadStorageList. Not adding again.", currSeqId.intValue);
                    }
                    queueThisPacket = NO;
                    */
                    [payloadStorageList addFullPayload:pcmAudioDataPayload];
                    
                    // If we're not waiting already, wait for this many more packets to come in before sending MissingsPacketsRequest (if any). Cuz the packets might come in "out of order" & in that case we won't need to notify the server that they're missing.
                    /*
                    if (mprDelayCtr <= 0) {
                        mprDelayCtr = numSkippedPackets + 1;
                        NSLog(@" Setting *mprDelayCtr* to: %d", mprDelayCtr);
                    }
                    */
                    
                    isWaitingOnMissingPackets = YES;
                    TOCK3;
                }
                
                /*
                NSLog(@"Time to send MissingPacketsRequest?");
                if ([payloadStorageList getMissingPayloads].count > 0) {
                    NSLog(@" Maybe! There's (%d) missingPayloads", (int)[payloadStorageList getMissingPayloads].count);
                    if (mprDelayTimer <= 0) {
                        NSArray *missingPayloads = [payloadStorageList getMissingPayloads];
                        NSLog(@"  Yes! mprDelayTimer Expired => Sending **MISSING PACKETS REQUEST** with port:%d, and ALL missing payloads(%d): %@", port, (int)missingPayloads.count, [payloadStorageList getMissingPayloadsSeqIdsAsHexString]);
                        [self sendMissingPacketsRequestWithPort:port AndMissingPayloads:missingPayloads];
                        mprDelayTimer = MPR_DELAY_RESET;
                    } else {
                        NSLog(@"  No! mprDelayTimer(%d) hasn't expired yet.", mprDelayTimer);
                    }
                } else {
                    NSLog(@" No! There are 0 MissingPayloads.");
                    mprDelayTimer = MPR_DELAY_RESET + 1;
                }
                TOCK4;
                */
                /*
                // Send Missing Packets?
                if ([payloadStorageList getMissingPayloads].count > 0) {
                    if (!isBurstMode) {
                        NSArray *missingPayloads = [payloadStorageList getMissingPayloads];
                        [self sendMissingPacketsRequestWithPort:port AndMissingPayloads:missingPayloads];
                        NSLog(@"NOT in Burst Mode. Sending **MISSING PACKETS REQUEST** with port:%d, and ALL missing payloads(%d): %@", port, (int)missingPayloads.count, [payloadStorageList getMissingPayloadsSeqIdsAsHexString]);
                        
                    } else {
                        NSLog(@"We're in BURST MODE. Not sending existing Missing Payloads.");
                    }
                } else {
                    NSLog(@"There are 0 MissingPayloads.");
                }
                */
                
                /*
                mprDelayCtr--;
                
                // Submit a Missing Packets Request (if we have any missing packets) // Note: MAYBE don't want to do this EVERY time, but it also shouldn't hurt...
                //if (!skipMissingPacketsRequestThisTimeThrough && missingPacketsSeqIdsList.count > 0) {
                NSArray *missingPayloads = [payloadStorageList getMissingPayloads];
                //if (!skipMissingPacketsRequestThisTimeThrough && missingPayloads.count ) {
                if (mprDelayCtr <= 0) {
                    NSLog(@" mprDelayCtr is <= 0. (%d). Possible to send Missing Packets Request", mprDelayCtr);
                    if ( !skipMissingPacketsRequestThisTimeThrough && missingPayloads.count > 0 ) {
                        //NSLog(@" Sending Missing Packets Request with port:%d, and missing packets: %@", port, [self getMissingPacketsSeqIdsAsHexString:missingPacketsSeqIdsList]);
                        NSLog(@"  Sending Missing Packets Request with port:%d, and missing payloads(%d): %@", port, (int)missingPayloads.count, [payloadStorageList getMissingPayloadsSeqIdsAsHexString]);
                        //[self sendMissingPacketsRequestWithPort:port AndMissingPackets:missingPacketsSeqIdsList];
                        [self sendMissingPacketsRequestWithPort:port AndMissingPayloads:missingPayloads];
                    } else {
                        NSLog(@"  Skipping sending Missing Packets Report this time through  OR  missingPayloads.count == 0");
                    }
                } else {
                    NSLog(@" mprDelayCtr is > 0. (%d). Waiting for it to reach 0 or less before sending Missing Packets Report", mprDelayCtr);
                }
                */
                
                
                
                /*
                if (queueThisPacket) {
                    // Send data to channel's circular buffer (Queue it up to be played)
                    [self.dgChannel putInCircularBufferAudioData:pcmAudioDataPayload.audioData];
                    lastQueuedSeqId = currSeqId;
                }
                */
                
                /*
                if (checkForReadyToQueuePacketsInStorageList) {
                    NSLog(@"checking for ready-to-quque packets in StorageList");
                    if (pcmAudioDataPayloadStorageList.count > 0) {
                        NSLog(@" found %d in StorageList", (int)pcmAudioDataPayloadStorageList.count);
                        SeqId *storedSeqId0 = ((PcmAudioDataPayload*)pcmAudioDataPayloadStorageList[0]).seqId;
                        NSLog(@" storedSeqId0: 0x%04x", storedSeqId0.intValue);
                        while ([storedSeqId0 isEqualToSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
                            NSLog(@"  Great! We've got a packet (0x%04x) in the StorageList that we can queue up now. Queueing it & Removing from Storage.", storedSeqId0.intValue);
                            // Queue it up!
                            [self.dgChannel putInCircularBufferAudioData:((PcmAudioDataPayload*)pcmAudioDataPayloadStorageList[0]).audioData];
                            lastQueuedSeqId = storedSeqId0;
                            
                            // Remove from Storage
                            [pcmAudioDataPayloadStorageList removeObjectAtIndex:0];
                            
                            // Get next storedSeqId (if exists)
                            if (pcmAudioDataPayloadStorageList.count > 0) {
                                storedSeqId0 = ((PcmAudioDataPayload*)pcmAudioDataPayloadStorageList[0]).seqId;
                            } else {
                                break;  // out of while loop
                            }
                        }
                    }
                }
                */
                
                
            }
        }
    }
}

-(void)queueThisPayload:(PcmAudioDataPayload*)payload {
    // Send data to channel's circular buffer (Queue it up to be played)
    //TICK;
    [self.dgChannel putInCircularBufferAudioData:payload.audioData];
    //TOCK;
    
    lastQueuedSeqId = payload.seqId;
}

-(void)checkForReadyToQueuePacketsInStorageList {
    NSLog(@" checking for ready-to-quque packets in StorageList");
    while ([payloadStorageList hasFullPayloadAtFirstElementWithThisSeqId:[[SeqId alloc] initWithInt:lastQueuedSeqId.intValue + 1]]) {
        NSLog(@"  Great! We've got a packet (0x%04x) in the StorageList that we can queue up now. Queueing it & Removing from the StorageList.", lastQueuedSeqId.intValue + 1);
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


-(float) getNumAudioSecondsFromNumAudioBytes:(uint32_t)numBytes {
    return numBytes / af.sampleRate / afSampleSizeInBytes / af.channels;
}

/*
-(uint32_t) getUInt32FromData:(NSData*)data AtOffset:(uint32_t)offset BigEndian:(Boolean)bigEndian {
    // Assumes bytes are in Little Endian order
    uint32_t length = sizeof(uint32_t);
    uint8_t tempBA[length];
    [data getBytes:tempBA range:NSMakeRange(offset, length)];

    if (bigEndian) {
        return CFSwapInt32BigToHost(*(uint32_t*)(tempBA));
    } else {
        return CFSwapInt32LittleToHost(*(uint32_t*)(tempBA));
    }
}

-(uint16_t) getUInt16FromData:(NSData*)data AtOffset:(uint32_t)offset BigEndian:(Boolean)bigEndian {
    // Assumes bytes are in Little Endian order
    uint32_t length = sizeof(uint16_t);
    uint8_t tempBA[length];
    [data getBytes:tempBA range:NSMakeRange(offset, length)];
    
    if (bigEndian) {
        return CFSwapInt16BigToHost(*(uint16_t*)(tempBA));
    } else {
        return CFSwapInt16LittleToHost(*(uint16_t*)(tempBA));
    }
    
}

-(uint8_t) getUInt8FromData:(NSData*)data AtOffset:(uint32_t)offset {
    uint32_t length = sizeof(uint8_t);
    uint8_t tempBA[length];
    [data getBytes:tempBA range:NSMakeRange(offset, length)];
    
    return tempBA[0];
}

-(void) appendInt:(int)i OfLength:(uint8_t)length ToData:(NSMutableData*)data BigEndian:(Boolean)bigEndian {
    // length is # of Bytes
    uint8_t b[length];
    
    // Check for possible data loss & warn user if so
    if (i > pow(2, length * 8)) {
        NSLog(@"*WARNING! Full int will not fit inside byte array! Data lost! i: %d, length: %d", i, length);
    }
    
    for (int ctr = 0; ctr < length; ctr++) {
        int pos = bigEndian ? length - 1 - ctr : ctr;  // e.g. bigEndian=>3,2,1,0 littleEndian=0,1,2,3
        b[pos] = (uint8_t) ((i & (0xFF << (8 * ctr))) >> (8 * ctr));  // e.g. 1st time thru loop => i & 0xFF, 2nd time => i & 0xFF00, etc., then shift back to right same amt.
    }
    
    [data appendBytes:b length:length];
}

-(void) appendNullTermString:(NSString*)str ToData:(NSMutableData*)data MaxLength:(int)maxLength {
    int length = MIN((int)str.length, maxLength);
    int i, j;
    uint8_t b[maxLength];
    
    for (i = 0; i < length; i++) {
        b[i] = [str characterAtIndex:i];
        [self appendInt:b[i] OfLength:1 ToData:data BigEndian:NO];
    }
    
    // Null-terminte it & fill rest with 0's, if there's room.
    for (j = i; j < maxLength; j++) {
        b[j] = 0x00;
        [self appendInt:b[j] OfLength:1 ToData:data BigEndian:NO];
    }
}

-(NSString*) getNullTermStringFromData:(NSData*)data AtOffset:(uint32_t)offset WithMaxLength:(uint32_t)maxLength {
    NSData *strData = [data subdataWithRange:NSMakeRange(offset, maxLength)];
    int i;
    for (i = 0; i < strData.length; i++) {
        uint8_t ba[1];
        [strData getBytes:&ba range:NSMakeRange(i, 1)];
        if (ba[0] == 0x00) {  // Null Terminator
            break;  // out of for loop
        }
    }
    
    return [[NSString alloc] initWithData:[strData subdataWithRange:NSMakeRange(0, i)] encoding:NSASCIIStringEncoding];
}
*/

-(void) createAndStartNewAudioControllerAndSetup {
    NSLog(@"createAndStartNewAudioControllerAndSetup");
    
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
        /*
        audioDescription.mFormatID          = kAudioFormatLinearPCM;
        audioDescription.mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioDescription.mChannelsPerFrame  = 2;
        audioDescription.mBytesPerPacket    = afSampleSizeInBytes*audioDescription.mChannelsPerFrame;
        audioDescription.mFramesPerPacket   = 1;
        audioDescription.mBytesPerFrame     = afSampleSizeInBytes*audioDescription.mChannelsPerFrame;
        audioDescription.mBitsPerChannel    = af.sampleSizeInBits;
        audioDescription.mSampleRate        = af.sampleRate;
        */
        // Note: see documentation for "AudioStreamBasicDescription" (Core Audio Data Types Reference)
        audioDescription.mFormatID          = kAudioFormatLinearPCM;
        audioDescription.mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
        audioDescription.mChannelsPerFrame  = 2;
        audioDescription.mBytesPerPacket    = afSampleSizeInBytes;
        audioDescription.mFramesPerPacket   = 1;
        audioDescription.mBytesPerFrame     = afSampleSizeInBytes;
        audioDescription.mBitsPerChannel    = af.sampleSizeInBits;
        audioDescription.mSampleRate        = af.sampleRate;

        
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
    NSLog(@"Play Fast Speed");
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
    NSLog(@"Play Normal Speed");
    [self.lblPlaybackSpeed setText:@"1x"];
    [self.lblPlaybackSpeed setTextColor:colorGreen];
    
    // Remove timePitch filters from our channel (if there's any)
    [_audioController removeFilter:self.timePitchFastFilter fromChannel:self.dgChannel];
    [_audioController removeFilter:self.timePitchSlowFilter fromChannel:self.dgChannel];
}

-(void) makeAudioPlaySlowSpeed {
    NSLog(@"Play Slow Speed");
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

-(void)onAppEnteredForeground {
    // Fill in Wi-Fi Connection Label
    NSDictionary *ssidInfo = [self fetchSSIDInfo];
    [self.wifiConnection setText:ssidInfo[@"SSID"]];
}

-(void)onServerStoppedStreaming {
    NSLog(@"onServerSToppedStreaming");

    isServerStreaming = NO;
    self.waitingForServerLabel.hidden = NO;  // Show the "Waiting for Server to Stream" label
    self.streamView.hidden = YES;  // Hide the streamView (lang selection, "start listening" button, etc)
    
    // We better "click" Stop Listening too, in case user was listening at the time.
    [self onStopListening];
}

-(void)onCurrentlyNotReceivingAudio {
    NSLog(@"onCurrentlyNotReceivingAudio");
    
    isReceivingAudio = NO;
    [self.lblReceivingAudio setTextColor:colorVeryLightGray];
}

-(void)onBurstModeFinished {
    //NSLog(@"onBurstModeFinished()");
    NSLog(@"---Burst Mode Finished---");
    isBurstMode = NO;
    
    // Send Missing Packets (if any)
    if ([payloadStorageList getMissingPayloads].count > 0) {
        NSArray *missingPayloads = [payloadStorageList getMissingPayloads];
        [self sendMissingPacketsRequestWithPort:audioDataPort AndMissingPayloads:missingPayloads];
        NSLog(@"Sending **MISSING PACKETS REQUEST** with port:%d, and ALL missing payloads(%d): %@", audioDataPort, (int)missingPayloads.count, [payloadStorageList getMissingPayloadsSeqIdsAsHexString]);
    } else {
        NSLog(@"No Missing Packets to Send. Ok.");
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
/*
-(void)sendMissingPackets {
    if ([payloadStorageList getMissingPayloads].count > 0) {
        if (!isBurstMode) {
            NSArray *missingPayloads = [payloadStorageList getMissingPayloads];
            [self sendMissingPacketsRequestWithPort:audioDataPort AndMissingPayloads:missingPayloads];
            NSLog(@"NOT in Burst Mode. Sending **MISSING PACKETS REQUEST** with port:%d, and ALL missing payloads(%d): %@", audioDataPort, (int)missingPayloads.count, [payloadStorageList getMissingPayloadsSeqIdsAsHexString]);
            
        } else {
            NSLog(@"We're in BURST MODE. Not sending existing Missing Payloads.");
        }
    } else {
        NSLog(@"There are 0 MissingPayloads.");
    }
}
*/

@end
