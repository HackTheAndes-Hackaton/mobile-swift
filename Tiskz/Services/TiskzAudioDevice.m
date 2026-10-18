#import "TiskzAudioDevice.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <stdatomic.h>

@implementation TiskzAudioDevice {
    id<RTCAudioDeviceDelegate> _delegate;
    AudioUnit _unit;
    double _rate;
    void *_capture;
    atomic_bool _recording, _playing;
}
- (instancetype)init {
    if ((self = [super init])) { _rate = 48000; atomic_init(&_recording, false); atomic_init(&_playing, false); }
    return self;
}
- (double)deviceInputSampleRate { return _rate; }
- (double)deviceOutputSampleRate { return _rate; }
- (NSTimeInterval)inputIOBufferDuration { return AVAudioSession.sharedInstance.IOBufferDuration; }
- (NSTimeInterval)outputIOBufferDuration { return AVAudioSession.sharedInstance.IOBufferDuration; }
- (NSInteger)inputNumberOfChannels { return 1; }
- (NSInteger)outputNumberOfChannels { return 1; }
- (NSTimeInterval)inputLatency { return AVAudioSession.sharedInstance.inputLatency; }
- (NSTimeInterval)outputLatency { return AVAudioSession.sharedInstance.outputLatency; }
- (BOOL)isInitialized { return _delegate != nil; }
- (BOOL)isPlayoutInitialized { return _unit != nil; }
- (BOOL)isRecordingInitialized { return _unit != nil; }
- (BOOL)isPlaying { return atomic_load(&_playing); }
- (BOOL)isRecording { return atomic_load(&_recording); }

static OSStatus recordInput(void *context, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *time, UInt32 bus, UInt32 frames, AudioBufferList *ignored) {
    TiskzAudioDevice *device = (__bridge TiskzAudioDevice *)context;
    if (frames > 16384 || !atomic_load(&device->_recording)) return noErr;
    AudioBufferList list = { .mNumberBuffers = 1, .mBuffers = {{ .mNumberChannels = 1, .mDataByteSize = frames * 2, .mData = device->_capture }} };
    OSStatus result = AudioUnitRender(device->_unit, flags, time, 1, frames, &list);
    if (result != noErr) return result;
    if (device->_delegate) result = device->_delegate.deliverRecordedData(flags, time, 1, frames, &list, NULL, nil);
    void (^tap)(NSData *, double) = device.onSamples;
    if (tap) { @autoreleasepool { tap([NSData dataWithBytes:device->_capture length:frames * 2], device->_rate); } }
    return result;
}
static OSStatus playOutput(void *context, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *time, UInt32 bus, UInt32 frames, AudioBufferList *data) {
    TiskzAudioDevice *device = (__bridge TiskzAudioDevice *)context;
    if (atomic_load(&device->_playing) && device->_delegate) return device->_delegate.getPlayoutData(flags, time, 0, frames, data);
    for (UInt32 i = 0; i < data->mNumberBuffers; i++) memset(data->mBuffers[i].mData, 0, data->mBuffers[i].mDataByteSize);
    return noErr;
}
- (BOOL)initializeWithDelegate:(id<RTCAudioDeviceDelegate>)delegate {
    if (_delegate) return YES;
    _delegate = delegate;
    _rate = AVAudioSession.sharedInstance.sampleRate;
    if (_rate < 8000) _rate = 48000;
    AudioComponentDescription description = { .componentType = kAudioUnitType_Output, .componentSubType = kAudioUnitSubType_VoiceProcessingIO, .componentManufacturer = kAudioUnitManufacturer_Apple };
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    if (!component || AudioComponentInstanceNew(component, &_unit) != noErr) { _delegate = nil; return NO; }
    UInt32 enable = 1, maxFrames = 16384;
    AudioStreamBasicDescription format = { .mSampleRate = _rate, .mFormatID = kAudioFormatLinearPCM, .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, .mBytesPerPacket = 2, .mFramesPerPacket = 1, .mBytesPerFrame = 2, .mChannelsPerFrame = 1, .mBitsPerChannel = 16 };
    AURenderCallbackStruct input = { recordInput, (__bridge void *)self }, output = { playOutput, (__bridge void *)self };
    BOOL ok = AudioUnitSetProperty(_unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enable, sizeof(enable)) == noErr &&
        AudioUnitSetProperty(_unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, sizeof(maxFrames)) == noErr &&
        AudioUnitSetProperty(_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &format, sizeof(format)) == noErr &&
        AudioUnitSetProperty(_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format, sizeof(format)) == noErr &&
        AudioUnitSetProperty(_unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &input, sizeof(input)) == noErr &&
        AudioUnitSetProperty(_unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &output, sizeof(output)) == noErr && AudioUnitInitialize(_unit) == noErr;
    _capture = calloc(maxFrames, 2);
    if (!ok || !_capture) { [self terminateDevice]; return NO; }
    return YES;
}
- (BOOL)initializePlayout { return _unit != nil; }
- (BOOL)initializeRecording { return _unit != nil; }
- (BOOL)startPlayout { atomic_store(&_playing, true); if (AudioOutputUnitStart(_unit) == noErr) return YES; atomic_store(&_playing, false); return NO; }
- (BOOL)startRecording { atomic_store(&_recording, true); if (AudioOutputUnitStart(_unit) == noErr) return YES; atomic_store(&_recording, false); return NO; }
- (BOOL)stopPlayout { atomic_store(&_playing, false); if (!atomic_load(&_recording) && _unit) AudioOutputUnitStop(_unit); return YES; }
- (BOOL)stopRecording { atomic_store(&_recording, false); if (!atomic_load(&_playing) && _unit) AudioOutputUnitStop(_unit); return YES; }
- (BOOL)terminateDevice {
    atomic_store(&_playing, false); atomic_store(&_recording, false);
    if (_unit) { AudioOutputUnitStop(_unit); AudioUnitUninitialize(_unit); AudioComponentInstanceDispose(_unit); _unit = nil; }
    _delegate = nil; if (_capture) { memset(_capture, 0, 16384 * 2); free(_capture); _capture = NULL; } return YES;
}
- (void)dealloc { [self terminateDevice]; }
@end
