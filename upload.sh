#!/bin/bash

Cyan='\033[0;36m'
Default='\033[0;m'

versionName=""
commitContent=""
confirmed="n"

getVersionName() {
read -p "Enter Version Name: " versionName

if test -z "$versionName"; then
getVersionName
fi
}

getCommitContent() {
read -p "Enter Commit  Content: " commitContent

if test -z "$commitContent"; then
commitContent
fi
}
getInfomation() {
getVersionName
getCommitContent

echo -e "\n${Default}================================================"
echo -e "  Version Name      :  ${Cyan}${versionName}${Default}"
echo -e "  Commit  Content   :  ${Cyan}${commitContent}${Default}"
echo -e "================================================\n"
}
echo -e "\n"
while [ "$confirmed" != "y" -a "$confirmed" != "Y" ]
do
if [ "$confirmed" == "n" -o "$confirmed" == "N" ]; then
getInfomation
fi
read -p "confirm? (y/n):" confirmed
done

git stash
git pull origin master --tags
git stash pop


VersionString=`grep -E 's.version.*=' JDNetWork.podspec`
VersionNumber=`tr -cd 0-9 <<<"$VersionString"`

VersionString=`grep -E 's.version.*=' JDNetWork.podspec`
LineNumber=`grep -nE 's.version.*=' JDNetWork.podspec | cut -d : -f1`
sed -i "" "${LineNumber}s/${VersionNumber}/${versionName}/g" JDNetWork.podspec


git add .
git commit -a -m ${commitContent}
git tag ${versionName}
git push origin master --tags

git pull origin master && pod repo push JDNetWork.podspec --verbose --allow- #warnings --use-libraries


