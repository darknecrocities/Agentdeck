#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <arpa/inet.h>

@interface CameraStreamer : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, assign) CGColorSpaceRef colorSpace;
@property (nonatomic, assign) double quality;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, strong) NSDate *startTime;
@end

@implementation CameraStreamer

- (instancetype)initWithQuality:(double)quality {
    if (self = [super init]) {
        self.ciContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
        self.colorSpace = CGColorSpaceCreateDeviceRGB();
        self.quality = quality > 0.1 ? quality : 0.65;
    }
    return self;
}

- (void)dealloc {
    if (self.colorSpace) {
        CGColorSpaceRelease(self.colorSpace);
    }
    [super dealloc];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) return;
    
    self.frameCount++;
    if (self.frameCount == 1) {
        self.startTime = [NSDate date];
    }
    
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    NSData *jpeg = [self.ciContext JPEGRepresentationOfImage:ciImage
                                                  colorSpace:self.colorSpace
                                                     options:@{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(self.quality)}];
    if (!jpeg || !jpeg.length) return;
    
    uint32_t len = (uint32_t)jpeg.length;
    uint32_t net_len = htonl(len);
    
    if (fwrite(&net_len, sizeof(net_len), 1, stdout) == 1) {
        fwrite(jpeg.bytes, 1, jpeg.length, stdout);
        fflush(stdout);
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        double quality = 0.65;
        if (argc > 1) {
            double q = atof(argv[1]);
            if (q >= 0.1 && q <= 1.0) quality = q;
        }
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (!device) {
            fprintf(stderr, "No camera device found\n");
            exit(1);
        }
        
        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (error || !input) {
            fprintf(stderr, "Failed to create camera input: %s\n", error.localizedDescription.UTF8String);
            exit(1);
        }
        
        AVCaptureSession *session = [[AVCaptureSession alloc] init];
        session.sessionPreset = AVCaptureSessionPreset1280x720;
        
        if (![session canAddInput:input]) {
            session.sessionPreset = AVCaptureSessionPresetMedium;
        }
        [session addInput:input];
        
        AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
        output.alwaysDiscardsLateVideoFrames = YES;
        output.videoSettings = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
        };
        
        CameraStreamer *streamer = [[CameraStreamer alloc] initWithQuality:quality];
        dispatch_queue_t queue = dispatch_queue_create("com.agentdeck.camerastream", DISPATCH_QUEUE_SERIAL);
        [output setSampleBufferDelegate:streamer queue:queue];
        
        if ([session canAddOutput:output]) {
            [session addOutput:output];
        } else {
            fprintf(stderr, "Cannot add camera output\n");
            exit(1);
        }
        
        [session startRunning];
        fprintf(stderr, "AgentDeck Hardware CameraStreamer running\n");
        
        dispatch_main();
    }
    return 0;
}
