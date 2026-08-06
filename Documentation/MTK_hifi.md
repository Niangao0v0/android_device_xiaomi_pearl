这是一份通过adb logcat获取运行时日志和grep命令搜索动态链接库中字符串后，得出的运行时描述。
本文档的所有结论都是基于对系统运行时行为的观察和推断，而非对二进制文件的逆向工程。
仅用于为开源社区提供 Mediatek 平台 Hi-Fi 通路移植的技术参考，请勿用于其他用途。

仅适用mt6895芯片的MTK hifi实现方案。

MTK 平台的高解析度音频（MTK hifi）并非通过高通那样的 direct_pcm 端口实现，
而是通过深度定制的软件栈，在 **被定制的AOSP音频组件** → **system_ext定制附加组件** → **HAL层** 协同工作，
实现audio_policy_configuration.xml中deep_buffer端口的动态采样率切换（可从 48kHz 提升至 96kHz或192kHz）。

通过poweramp走Hi-res通道播放192kHz音频时adb logcat | grep hifi可以得到以下执行流程：

1. 应用请求高采样率流 → libaudioclient.so 调用 AudioSystem::setParameters("hifi_dac=on")

logcat      AudioSystem: +setParameters(): hifi_dac=on
这个system/lib64/libaudioclient.so是AOSP组件，但是MTK修改了其源码，使其可以产生hifi_dac=on标志

2. system_ext/lib64/libaudiopolicycustomextensions.so策略响应
AudioPolicyManagerCustomImpl 接收参数，设置内部状态 hifi_state=1
虽然他的ABI与高版本安卓断裂，但是可以通过写一个shim解决（见Release里的压缩包）。

logcat      AudioPolicyManagerCustomImpl: POLICY_SET_HIFI_STATE set hifi state = 1

3. system_ext/lib64/libaudiopolicycustomextensions.so调用AudioSystem::setParameters("hifi_state=1")设置第二个hifi标志

logcat      AudioSystem: +setParameters(): hifi_state=1 

3. system/lib64/libaudioflinger.so广播hifi_state=1标志
通过 AudioSystem::setParameters("hifi_state=1") 广播给所有与音频有关的 HAL 模块
由system/lib64/libaudioflinger.so执行。这是一个AOSP组件，目前没有发现他被mtk定制或修改的迹象

logcat      AudioFlinger: +mAudioHwDevs(primary)->setParameters(): hifi_state=1

4. 采样率切换。
流开始时，system_ext/lib64/libaudiopolicycustomextensions.so调用 hifiAudio_startOutputSamplerate()

logcat      AudioPolicyManagerCustomImpl: hifiAudio_startOutputSamplerate() +output = 21  portId = 4526 samplerate = 192000 HifiState = 1 stream 3, session 30745

5. audio.primary.mediatek.so会尝试触碰一个不存在的hifi_dac_output设备（这个设备在Xiaomi系统中也不存在）

logcat      AudioALSADeviceConfigManager: ApplyDeviceTurnonSequenceByName  DeviceName = hifi_dac_output descriptor == NULL

这里触碰失败不影响后续的采样率升高

6. HAL层重新配置采样率

logcat      AudioALSAPlaybackHandlerNormal: setScreenState(), flag = 0x8, mode = 1, sample_rate(source/target) = 192000/192000, buffer_size(source/target) = 32768/65536, device_support_hifi = 1

0. 一些hifi配置文件：
vendor/etc/audio_param/SoundEnhancement_ParamUnitDesc.xml
vendor/etc/audio_param/SoundEnhancement_AudioParam.xml
vendor.prop中还要添加：ro.vendor.mtk_hifiaudio_support=1和ro.vendor.audio.hifi=true

对于我们移植来看，我们可以将system_ext/lib64/libaudiopolicycustomextensions.so及其依赖一起放进lineageOS中，
但是不清楚Mediatek是如何修改system/lib64/libaudioclient.so这个关键的Hifi发令枪的。
没有他发出hifi_dac=on标志，后续我们加进去的闭源库就无法工作。

====================================================
以下是AI对AOSP的修改，用于实现3.5mm耳机输出音频的采样率随流切换策略。
这是一个个人研究项目，非官方发布，使用风险自负。
但是流还是走的deep_buffer的mix混音器，没有写一个类似高通的direct_pcm硬件直通端口出来
以下代码未经充分测试，可能出现偶发性爆音、卡顿等现象。
**如您希望测试，请务必保护好听力：不要靠近听筒、首次试听不要将耳机完全插入耳内！不要在3.5mm耳机口插入昂贵设备！**

通过扬声器播放似乎无法自动切换。而且扬声器只支持44100和48000两个采样率。
仅测试了3.5mm输出，未测试其他硬件输出。

已知问题：
1. 在88200、96000、176400、192000高采样率下，会出现稳定的卡顿掉帧，似乎与缓冲区大小未能随采样率一同切换有关。
但是解决以上问题会带来更多Bug, 一时半会也修不好，就告辞了。
但是拿来听44100和48000的是没问题的。

2. 采样率切换有时会有迟滞，或切换后无声，您需要来回切换几次。
-------------------------------------------------------
使用前请确保device/xiaomi/mt6895-common/vendor.prop中
添加了：
ro.vendor.mtk_hifiaudio_support=1
ro.vendor.audio.hifi=true

修改文件: 

1. frameworks/av/services/audioflinger/AudioFlinger.cpp: 1731（未在deamonSamplingRate.tar.gz中）
说明：Lineage会拦截应用向HAL发出的带有sampling_rate=%u字样的键，注释掉它

```cpp
- String8(AudioParameter::keySamplingRate), 
+ //String8(AudioParameter::keySamplingRate),
```

2. frameworks/av/services/audioflinger/Threads.h: 1677（在deamonSamplingRate.tar.gz中）

说明：这里添加了两个成员，用于为后续的前导静音填充帧服务
```cpp
+ protected:
+     bool mNeedSilencePadding;          // 是否需要填充静音（true 表示需要）
+     size_t mSilenceFramesRemaining;    // 剩余需要填充的静音帧数（每次递减）
```

3. frameworks/av/services/audioflinger/Threads.cpp（在deamonSamplingRate.tar.gz中）

说明：这里初始化了以上两个前导静音填充帧成员
2296: 
```cpp
- mIsTimestampAdvancing(kMinimumTimeBetweenTimestampChecksNs)
+ mIsTimestampAdvancing(kMinimumTimeBetweenTimestampChecksNs),
+ mNeedSilencePadding(false),
+ mSilenceFramesRemaining(0)
```

说明：这里的修改是为了向MTK的HAL传递HIFI键和采样率键
2941: 
```cpp
+ if ((mOutput->flags & AUDIO_OUTPUT_FLAG_DEEP_BUFFER) || (mOutput->flags & AUDIO_OUTPUT_FLAG_MMAP_NOIRQ)) {
+   android::String8 params;
+   params.appendFormat("hifi_state=1;sampling_rate=%u", track->sampleRate());
+   AudioSystem::setParameters(mId, params);
+ }
```


说明：删除if内status == NO_ERROR的条件是因为，MTK的HAL设计之初就不是这么直接传递sampling_rate=%u键用的，
      所以他压根不会返回status == NO_ERROR。他不返回就没法进入以下刷新流程，音频播放就会出现异常。
6550: 
```cpp
- if (status == NO_ERROR && reconfig) {
+ if (reconfig) {
+   audio_output_flags_t flags = mOutput->flags;
+   if ((flags & AUDIO_OUTPUT_FLAG_DEEP_BUFFER) || (flags & AUDIO_OUTPUT_FLAG_MMAP_NOIRQ)) {
+       mOutput->standby();// 1. 强制 standby，清空 HAL 缓冲，避免爆音
+       setStandby_l();
+       mBytesWritten = 0;
+       // ========== 静音前导填充（Pre-roll Silence），不添加会导致播放初期爆音==========
+       mSilenceFramesRemaining = (mSampleRate * 3) / 4;//这里是静音播放前的0.75秒，您可以尝试压缩静音填充时长
+       mNeedSilencePadding = true;//通知主循环下次写入时要先填静音
+       // ========== 静音前导填充结束 ==========
+   }
```


说明：这里实现了前导静音填充，以掩盖采样率切换后、音频播放最初的“噗”爆音。
3572: 
```cpp
+   if (mNeedSilencePadding && mSilenceFramesRemaining > 0) {
+       // ① 本次最多写一个周期的帧数（避免一次写太多）
+       size_t framesToWrite = std::min(mSilenceFramesRemaining, (size_t)mNormalFrameCount);
+       size_t bytesToWrite = framesToWrite * mFrameSize;
+ 
+       // ② 将 mSinkBuffer 清零（从开头开始）
+       memset(mSinkBuffer, 0, bytesToWrite);
+ 
+       ssize_t written = 0;
+       // ③ 根据是否存在 NBAIO sink 选择写入接口
+       if (mNormalSink != 0) {
+           // 通过 NBAIO sink 写入（返回帧数）
+           ssize_t framesWritten = mNormalSink->write(mSinkBuffer, framesToWrite);
+           if (framesWritten > 0) {
+               written = framesWritten * mFrameSize;
+           } else {
+               written = framesWritten;   // 负错误码
+           }
+       } else {
+           // 直接写入 HAL（返回字节数）
+           written = mOutput->write(mSinkBuffer, bytesToWrite);
+       }
+ 
+       // ④ 处理写入结果
+       if (written > 0) {
+           size_t writtenFrames = written / mFrameSize;
+           mSilenceFramesRemaining -= writtenFrames;
+           mBytesWritten += written;      // 保持统计一致
+           if (mSilenceFramesRemaining == 0) {
+               mNeedSilencePadding = false;
+           }
+       }
+       mInWrite = false;
+       return written;  // 本次循环结束，不再写真实音频
+   }
```