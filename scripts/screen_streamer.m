#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <arpa/inet.h>

@interface ScreenStreamer : NSObject <SCStreamOutput, SCStreamDelegate>
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, assign) CGColorSpaceRef colorSpace;
@property (nonatomic, assign) double quality;
@end

@implementation ScreenStreamer

- (instancetype)initWithQuality:(double)quality {
    if (self = [super init]) {
        self.ciContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
        self.colorSpace = CGColorSpaceCreateDeviceRGB();
        self.quality = quality > 0.1 ? quality : 0.6;
    }
    return self;
}

- (void)dealloc {
    if (self.colorSpace) {
        CGColorSpaceRelease(self.colorSpace);
    }
    [super dealloc];
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type != SCStreamOutputTypeScreen) return;
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) return;
    
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    NSData *jpeg = [self.ciContext JPEGRepresentationOfImage:ciImage
                                                  colorSpace:self.colorSpace
                                                     options:@{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(self.quality)}];
    if (!jpeg || !jpeg.length) return;
    
    uint32_t len = (uint32_t)jpeg.length;
    uint32_t net_len = htonl(len);
    
    // Write 4-byte big-endian length followed by JPEG payload
    if (fwrite(&net_len, sizeof(net_len), 1, stdout) == 1) {
        fwrite(jpeg.bytes, 1, jpeg.length, stdout);
        fflush(stdout);
    }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    if (error) {
        fprintf(stderr, "ScreenCaptureKit stream stopped with error: %s\n", error.localizedDescription.UTF8String);
    }
    exit(0);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int width = 1280;
        int targetFps = 30;
        double quality = 0.6;
        
        if (argc > 1) {
            int w = atoi(argv[1]);
            if (w >= 640 && w <= 2560) width = w;
        }
        if (argc > 2) {
            int fps = atoi(argv[2]);
            if (fps >= 10 && fps <= 60) targetFps = fps;
        }
        if (argc > 3) {
            double q = atof(argv[3]);
            if (q >= 0.1 && q <= 1.0) quality = q;
        }
        
        [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent * _Nullable shareableContent, NSError * _Nullable error) {
            if (error || !shareableContent.displays.count) {
                fprintf(stderr, "ScreenCaptureKit error: %s\n", error ? error.localizedDescription.UTF8String : "No display found");
                exit(1);
            }
            
            SCDisplay *display = shareableContent.displays.firstObject;
            SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
            
            SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
            config.width = width;
            config.height = (int)((double)width * ((double)display.height / (double)display.width));
            config.minimumFrameInterval = CMTimeMake(1, targetFps);
            config.queueDepth = 3;
            config.showsCursor = YES;
            
            SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:nil];
            ScreenStreamer *streamer = [[ScreenStreamer alloc] initWithQuality:quality];
            
            dispatch_queue_t queue = dispatch_queue_create("com.agentdeck.screenstream", DISPATCH_QUEUE_SERIAL);
            NSError *streamErr = nil;
            [stream addStreamOutput:streamer type:SCStreamOutputTypeScreen sampleHandlerQueue:queue error:&streamErr];
            
            if (streamErr) {
                fprintf(stderr, "Failed to add stream output: %s\n", streamErr.localizedDescription.UTF8String);
                exit(1);
            }
            
            [stream startCaptureWithCompletionHandler:^(NSError * _Nullable startErr) {
                if (startErr) {
                    fprintf(stderr, "Failed to start capture: %s\n", startErr.localizedDescription.UTF8String);
                    exit(1);
                }
                fprintf(stderr, "AgentDeck Hardware ScreenStreamer running (%d x %d @ %d FPS)\n", (int)config.width, (int)config.height, targetFps);
            }];
        }];
        
        dispatch_main();
    }
    return 0;
}
