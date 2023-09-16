#!/bin/bash
# 指定一个带有deploy.txt任务文件的目录，进行打包，并提供解包
# deploy.txt格式：有多少个需部署的目录就分多少行，每行2或3段
#   第1段：临时名称，避免相同名称冲突
#   第2段：打包设备中的源路径
#   第3段：部署设备中的目标路径，此段为空表示目标路径与源路径相同

prepare()
{
    if [ $# -lt 1 ]; then
        exit 0
    fi
    taskPath=$1/deploy.txt
    if [ -e "${taskPath}" ]; then
        : # 必须含有deploy.txt
    else
        exit 0
    fi

    srcName=$(basename $1)
    tarName=${srcName}.tar
    dirName=temp
    if [ -z "${BOX_PATH}" ]; then
        BOX_PATH=~
    fi
    temp=${BOX_PATH}/.temp/${dirName}
    system=$(uname)
}

genDeployPack()
{
    rm -rf ${temp}
    mkdir -p ${temp}
    deployTool=${BOX_PATH}/.temp/${srcName}_deploy
    touch ${deployTool}
    echo "#!/bin/bash" > ${deployTool}
    echo 'cd $(dirname $0)' >> ${deployTool}
    echo "rm -rf ${tarName}" >> ${deployTool}
    # echo "dd if=\""'$0'"\" of=\"${tarName}\" bs=1 skip=" >> ${deployTool} # bs=1太慢
    echo "tail -c + "'$0'" > ${tarName}" >> ${deployTool}
    echo "rm -rf ${dirName}" >> ${deployTool}
    echo "tar xf ${tarName} && cd ${dirName}" >> ${deployTool}
    while IFS= read -r line || [[ -n "${line}" ]]; do
        read -ra segments <<< "${line}"
        srcBaseName=${segments[0]}
        eval src=${segments[1]} # eval解析一层变量
        dst=${segments[2]}
        if [ -z ${dst} ]; then
            dst=${segments[1]}
        fi

        cp -r ${src} ${temp}/${srcBaseName}
        echo "cp -rf ${srcBaseName} ${dst}" >> ${deployTool}
    done < ${taskPath}
    echo "rm -rf ${dirName} ${tarName}" >> ${deployTool}
    echo "exit" >> ${deployTool}
}

calcOff()
{
    if [ "${system}" == "Darwin" ]; then
        fileSize=$(stat -f "%z" ${deployTool})
    else
        fileSize=$(stat -c "%s" ${deployTool})
    fi
    fileSizeWithLen=$(expr ${fileSize} + ${#fileSize} + 1)  # +1因为tail计数从1开始
    sed -i "" "s/tail -c +/tail -c +${fileSizeWithLen}/g" ${deployTool}
}

finish()
{
    cd ${BOX_PATH}/.temp
    tar cf ${tarName} ${dirName}
    cat ${tarName} >> ${deployTool}
    rm -rf ${temp} ${tarName}
    chmod +x ${deployTool}
    echo "generate ${deployTool} successfully"
}

prepare $*
genDeployPack
calcOff
finish
