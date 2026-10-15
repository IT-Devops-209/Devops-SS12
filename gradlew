#!/bin/sh
#
# Gradle Wrapper Script (Unix / GitHub Actions)
#
APP_HOME=$(cd "$(dirname "$0")" && pwd)
CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar

if [ -f "$CLASSPATH" ]; then
    exec java $DEFAULT_JVM_OPTS $JAVA_OPTS $GRADLE_OPTS \
        "-Dorg.gradle.appname=$(basename "$0")" \
        -classpath "$CLASSPATH" \
        org.gradle.wrapper.GradleWrapperMain \
        "$@"
else
    # Fallback to system gradle on GitHub runner if wrapper jar is omitted
    exec gradle "$@"
fi
