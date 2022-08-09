#import "VideoThumbnailPlugin.h"
#if __has_include(<video_thumbnail/video_thumbnail-Swift.h>)
#import <video_thumbnail/video_thumbnail-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "video_thumbnail-Swift.h"
#endif



@implementation VideoThumbnailPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftVideoThumbnailPlugin registerWithRegistrar:registrar];
}

@end
