- 这是一份通过adb logcat获取运行时日志和grep命令搜索动态链接库中字符串后，得出的运行时描述。
- 本文档的所有结论都是基于对系统运行时行为的观察和推断，而非对二进制文件的逆向工程。
- 仅用于为开源社区提供 Mediatek 平台 Hi-Fi 通路移植的技术参考，请勿用于其他用途。

- 仅适用mt6895芯片的MTK hifi实现方案。

- MTK 平台的高解析度音频（MTK hifi）并非通过高通那样的 direct_pcm 端口实现，
- 而是通过深度定制的软件栈，在 **被定制的AOSP音频组件** → **system_ext定制附加组件** → **HAL层** 协同工作，
- 实现audio_policy_configuration.xml中deep_buffer端口的动态采样率切换（可从 48kHz 提升至 96kHz或192kHz）。

- 通过poweramp走Hi-res通道播放192kHz音频时adb logcat | grep hifi可以得到以下执行流程：

1. 应用请求高采样率流 → libaudioclient.so 调用 AudioSystem::setParameters("hifi_dac=on")
```
logcat      AudioSystem: +setParameters(): hifi_dac=on
```
- 这个system/lib64/libaudioclient.so是AOSP组件，但是MTK修改了其源码，使其可以产生hifi_dac=on标志

2. system_ext/lib64/libaudiopolicycustomextensions.so策略响应
- AudioPolicyManagerCustomImpl 接收参数，设置内部状态 hifi_state=1
- 虽然他的ABI与高版本安卓断裂，但是可以通过写一个shim解决（见Release里的压缩包）。
```
logcat      AudioPolicyManagerCustomImpl: POLICY_SET_HIFI_STATE set hifi state = 1
```
3. system_ext/lib64/libaudiopolicycustomextensions.so调用AudioSystem::setParameters("hifi_state=1")设置第二个hifi标志
```
logcat      AudioSystem: +setParameters(): hifi_state=1 
```
3. system/lib64/libaudioflinger.so广播hifi_state=1标志
- 通过 AudioSystem::setParameters("hifi_state=1") 广播给所有与音频有关的 HAL 模块
- 由system/lib64/libaudioflinger.so执行。这是一个AOSP组件，目前没有发现他被mtk定制或修改的迹象
```
logcat      AudioFlinger: +mAudioHwDevs(primary)->setParameters(): hifi_state=1
```
4. 采样率切换。
- 流开始时，system_ext/lib64/libaudiopolicycustomextensions.so调用 hifiAudio_startOutputSamplerate()
```
logcat      AudioPolicyManagerCustomImpl: hifiAudio_startOutputSamplerate() +output = 21  portId = 4526 samplerate = 192000 HifiState = 1 stream 3, session 30745
```
5. audio.primary.mediatek.so会尝试触碰一个不存在的hifi_dac_output设备（这个设备在Xiaomi系统中也不存在）
```
logcat      AudioALSADeviceConfigManager: ApplyDeviceTurnonSequenceByName  DeviceName = hifi_dac_output descriptor == NULL
```
- 这里触碰失败不影响后续的采样率升高

6. HAL层重新配置采样率
```
logcat      AudioALSAPlaybackHandlerNormal: setScreenState(), flag = 0x8, mode = 1, sample_rate(source/target) = 192000/192000, buffer_size(source/target) = 32768/65536, device_support_hifi = 1
```
0. 一些hifi配置文件：
```
vendor/etc/audio_param/SoundEnhancement_ParamUnitDesc.xml
vendor/etc/audio_param/SoundEnhancement_AudioParam.xml
vendor.prop中还要添加：ro.vendor.mtk_hifiaudio_support=1和ro.vendor.audio.hifi=true
```
- 对于我们移植来看，我们可以将system_ext/lib64/libaudiopolicycustomextensions.so及其依赖一起放进lineageOS中，
- 但是不清楚Mediatek是如何修改system/lib64/libaudioclient.so这个关键的Hifi发令枪的。
- 没有他发出hifi_dac=on标志，后续我们加进去的闭源库就无法工作。

-------------------------------------------------------
-------------------------------------------------------

- 以下是AI对AOSP的修改，用于实现3.5mm耳机输出音频的采样率随流切换策略。
- 这是一个个人研究项目，非官方发布，使用风险自负。
- 但是流还是走的deep_buffer的mix混音器，没有写一个类似高通的direct_pcm硬件直通端口出来
- 以下代码未经充分测试，不保证没有偶发性爆音、卡顿等听力和设备损失现象。
- **如您希望测试，请务必保护好听力：不要靠近听筒、首次试听不要将耳机完全插入耳内！不要在3.5mm耳机口插入昂贵设备！**

- 通过扬声器播放无法切换采样率。而且扬声器似乎不支持48000以上的采样率。
- 仅测试了3.5mm输出，未测试其他硬件输出。

-------------------------------------------------------
- 使用前请确保device/xiaomi/mt6895-common/vendor.prop中

添加了：
```
ro.vendor.mtk_hifiaudio_support=1
ro.vendor.audio.hifi=true
```

**修改文件: **

1. frameworks/av/services/audioflinger/AudioFlinger.cpp: 1731
- 说明：Lineage会拦截应用向HAL发出的带有sampling_rate=%u字样的键，去掉它

```cpp
- String8(AudioParameter::keySamplingRate), 
```

2. frameworks/av/services/audioflinger/Threads.cpp（附在同目录文件夹中，可对应查看修改）

- 说明：这是实现动态采样率的关键：向MTK的HAL**传递hifi_state键和sampling_rate键**。
- 一定要筛选音频流的FLAG，MTK的HAL压根没有对非deep_buffer音频流做采样率切换逻辑，这是切换初期爆音的根源。
- 曾经尝试在切换初期**写全0静音帧**的做法只是**治标不治本**。

2937: 
```cpp
+ if ((mOutput->flags & AUDIO_OUTPUT_FLAG_DEEP_BUFFER) || (mOutput->flags & AUDIO_OUTPUT_FLAG_MMAP_NOIRQ)) {
+   android::String8 params;
+   params.appendFormat("hifi_state=1;sampling_rate=%u", track->sampleRate());
+   status = sendSetParameterConfigEvent_l(params);
+ }
```

- 说明：删除if内status == NO_ERROR的条件是因为，MTK的HAL设计之初就不是这么直接传递sampling_rate=%u键用的，
- 所以他压根不会返回status == NO_ERROR。他不返回就没法进入以下刷新流程，音频播放就会出现变速、变调。

6510: 
```cpp
- if (status == NO_ERROR && reconfig) {
+ if (reconfig) {
```

- 说明：将音轨的主缓冲区重置为当前有效的 mSinkBuffer，使其回到普通混音路径，而不仅仅是打印日志。
- MTK HAL的采样率有两档，48000及以下为低档，48000（不含）为高档。
- 不更改此处会导致首次跨档位采样率切换时，第一次切换后无声。

5940：
```cpp
- ALOGW("prepareTracks_l(): track(%d) attached to effect but no chain found on "
-         "session %d",
-         trackId, track->sessionId());
+ track->setMainBuffer(static_cast<float*>(mSinkBuffer));
```

3. frameworks/av/media/libaudiohal/impl/StreamHalHidl.cpp: 477

- 说明：HAL内硬编码了两档buffer_size大小，48000Hz及以下是48KB，48000Hz以上的高采样率是64KB
- HAL在强制切换采样率后会自己调整buffer_size，只有HIDL是个数据卡点：HIDL只会在数据流建立的第一次从HAL获取buffer_size大小
- 由于强行切换采样率，HIDL的数据流还是延续音频流最初的那个小buffer_size
- AOSP上层音频框架想通过HIDL的小水管写超出其容量的数据，是导致高采样率下声音卡顿的根源。
- 我们直接硬编码成HAL内最大档位的buffer_size，但丧失了根据音频内容动态申请的能力，每条音频流无论播放什么都固定占用64KB内存。

```cpp
- size_t bufferSize;
+ size_t bufferSize = 65536;
- if ((status = getCachedBufferSize(&bufferSize)) != OK) {
-     return status;
- }
- if (bytes > bufferSize) bufferSize = bytes;
```

- TODO: 最好的做法是在这里实现一套动态的音频流检测buffer_size、销毁音频流、重新读取HAL值并扩容的逻辑。
- 但是这涉及跨进程通信，搞不好的话HAL就会读写空指针然后崩溃重启。
- 所以这一处修改没有普适性，需要为不同的Mediatek HAL手动硬编码最大值。
- 欢迎各位有兴趣的同学优化代码！