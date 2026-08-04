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