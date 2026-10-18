#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

/// One VoiceProcessingIO stream feeds WebRTC and, only with consent, a bounded RAM buffer.
@interface TiskzAudioDevice : NSObject <RTCAudioDevice>
@property(nonatomic, copy, nullable) void (^onSamples)(NSData * _Nonnull pcm, double sampleRate);
@end
