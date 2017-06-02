#!/usr/bin/env groovy

stage 'Build iOS App'
node('macOS') {
    def changelog = getChangeLog currentBuild
    slackSend "Building ${env.JOB_NAME} #${env.BUILD_NUMBER} \n Change Log: \n ${changelog}"

    try {
        checkout scm
        sh 'git submodule update --init'
        unlockKeychainMac "~/Library/Keychains/login.keychain-db"
        sh "xcodebuild -project \"ZeroTier One/ZeroTier One.xcodeproj\" -scheme \"ZeroTier One\" -configuration Debug CONFIGURATION_BUILD_DIR=\"${env.WORKSPACE}/build\" clean"
        sh 'rm -rf build/'
        sh "xcodebuild -project \"ZeroTier One/ZeroTier One.xcodeproj\" -scheme \"ZeroTier One\" -configuration Debug CONFIGURATION_BUILD_DIR=\"${env.WORKSPACE}/build\""
        slackSend color: "#00ff00", message: "${env.JOB_NAME} #${env.BUILD_NUMBER} Complete (<${env.BUILD_URL}|Show More...>)"
    }
    catch (err) {
        currentBuild.result = "FAILURE"
        slackSend color: "#ff0000", message: "${env.JOB_NAME} is broken (<${env.BUILD_URL}|Open>)"
        throw err
    }
}
