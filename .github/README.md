目前已经知晓但未解决的问题：

1. SElinux还处于宽容状态，否则无法开机

2. keymint是软件实现，还未调用MI TEE环境

3. 指纹不可用

4. MindTheGApps无法adb sideload侧载

本项目将会持续开发。但出于一些时间原因，不一定能够及时修复Bug与跟进上游。


如果您想要为Pearl贡献代码，修复Bug, 以下是一些编译前处理流程。**仅针对本仓库适用**

所有编译前处理文件，都在Release里。（因为直接放在仓库中会有一点问题）

0. 按照https://github.com/LineageOS/android/tree/lineage-23.2 先把lineage的repo初始化好

1. 将local_manifests.xml文件放入
 
    .repo/local_manifest/中
   
2. repo sync
   
    （此时需要等待很久，强烈建议你将repo的全部线程用-j都开出来，因为默认只有4线程，太慢了）
   
3. 将blob-patches文件夹、propritary-files.txt、vendor.prop文件放入deivce/xiaomi/mt6895-common目录，替换原有文件

4. **在device/xiaomi/pearl目录** 中运行：
 
   extract-files.py /你使用dumpyara解包的Pearl_OS3.0.3固件目录

5. 在**源码根目录**运行 patchelf.sh

6. 将shim文件夹放入/vendor/xiaomi/mt6895-common/propritary/中

7. 为vendor/xiaomi/mt6895-common/Android.bp中的模块"libsink-mtk"添加一个shared_libs:
    
    添加："libaudiotrack_shim",

8. 按照https://github.com/XagaForge/ 中的两个Required patches操作进行修补

9. 准备工作到此为止。接下来就是构建环节。
    构建方法与编译环境请参照Lineage官网任意机型的教程

    若您发现任何按照本流程出现的编译报错，欢迎提出issue, 以方便修改完善本教程。


刷入：
刷入脚本已附在Release的压缩包中。第一次刷入请全部用fastboot命令刷入。底包：HyperOS_3.0.3

如果出现任何不能进入系统的情况，音量上键与电源键同时按，进入lineage_recovery,

advanced-->启用adb

adb pull /sys/fs/pstore

看看 pmsg-ramoops-0 ，可能会对你有所帮助
