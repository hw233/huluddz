## 1.启动方式
* 启动脚本为 r.sh,启动需要killall命令,脚本会杀掉本机器上所有target命名的执行文件启动的进程(本项目 target 为gameSvr_ddz_2021)
* 启动脚本执行需要传入环境参数，传入不同参数会使用不同的config文件
* local为本机调试，debug为断点调试，线上使用publish 或者 不传入环境参数
```
##例如本地启动项目
sh r.sh local
```
## 2.调试相关 vscode
* 调试需要安装插件 skynet Debugger 目前适配了1.0.1版本
* 调试需要填写 launch.json 本项目参数相关 
```
   "configurations": [
        {
            "name": "skynet debugger",
            "type": "lua",
            "request": "launch",
            "workdir": "${workspaceFolder}",
            "program": "./server/gameSvr_ddz_2021",
            "config": "./config.debug",
            "service": "./server/service"
        }
    ]
```
* 之后就可以使用vscode的调试功能进行调试
* 调试插件 开源地址 https://github.com/colinsusie/skynetda 