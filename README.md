# ACVM

A simple launcher for running ARM64 VM using QEMU on Apple silicon.

The launcher embedded a pre-built binary of QEMU based on [the patches](https://patchwork.kernel.org/project/qemu-devel/list/?series=392975) from [Alexander Graf](https://twitter.com/_AlexGraf).

You can download the Windows 10 on ARM from [here](https://www.microsoft.com/en-us/software-download/windowsinsiderpreviewARM64), and drag the VHDX file to the main image area to boot it.

To get internet working, please follow [@niw's guide](https://gist.github.com/niw/e4313b9c14e968764a52375da41b4278#enable-the-internet), make sure you use `virtio-win-0.1.190.iso` or later (I tried 0.1.185, and that one crashed the VM).
