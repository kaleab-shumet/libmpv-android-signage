#include <jni.h>
#include <cstdlib>
#include <cstdio>
#include <ctime>
#include <clocale>
#include <atomic>

#include <mpv/client.h>

#include <pthread.h>

extern "C" {
    #include <libavcodec/jni.h>
}

#include "log.h"
#include "jni_utils.h"
#include "event.h"
#include "globals.h"

#define ARRAYLEN(a) (sizeof(a)/sizeof(a[0]))

// Update the JNI functions to accept a jlong parameter, which will be a
// pointer to the MPVInstance
extern "C" {
    jni_func(jlong, nativeCreate, jobject thiz, jobject appctx);
    jni_func(void, nativeInit, jlong instance);
    jni_func(void, nativeDestroy, jlong instance);
    jni_func(void, nativeCommand, jlong instance, jobjectArray jarray);
    jni_func(jint, nativeRequestLogMessages, jlong instance, jstring jlevel);
};

static void prepare_environment(JNIEnv *env, MPVInstance* instance) {
    setlocale(LC_NUMERIC, "C");

    if (env->GetJavaVM(&instance->vm) == JNI_OK && instance->vm)
        av_jni_set_java_vm(instance->vm, nullptr);

    if (instance->appCtx)
        av_jni_set_android_app_ctx(instance->appCtx, nullptr);

    init_methods_cache(env);
}

jni_func(jlong, nativeCreate, jobject thiz, jobject appctx) {
    auto instance = new MPVInstance();
    instance->event_thread_id = 0;
    instance->event_thread_request_exit = false;
    instance->destroy_on_event_thread_exit = false;
    instance->mpv = nullptr;
    instance->vm = nullptr;
    instance->javaObject = nullptr;
    instance->appCtx = nullptr;
    instance->surface = nullptr;
    instance->javaObject = env->NewGlobalRef(thiz);
    instance->appCtx = env->NewGlobalRef(appctx);
    prepare_environment(env, instance);

    instance->mpv = mpv_create();
    if (!instance->mpv) {
        if (instance->appCtx)
            env->DeleteGlobalRef(instance->appCtx);
        if (instance->javaObject)
            env->DeleteGlobalRef(instance->javaObject);
        delete instance;
        return 0;
    }

    // Signage players run 24/7: verbose logging costs CPU and floods logcat, and
    // "v" also prints the URLs being opened. Apps can raise it with requestLogMessages().
    mpv_request_log_messages(instance->mpv, "warn");
    return reinterpret_cast<jlong>(instance);
}

void destroy_mpv_instance(JNIEnv *env, MPVInstance *instance) {
    mpv_terminate_destroy(instance->mpv);
    instance->mpv = nullptr;
    if (instance->surface)
        env->DeleteGlobalRef(instance->surface);
    if (instance->appCtx)
        env->DeleteGlobalRef(instance->appCtx);
    if (instance->javaObject)
        env->DeleteGlobalRef(instance->javaObject);
    delete instance;
}

jni_func(void, nativeInit, jlong instance) {
    auto mpv_instance = reinterpret_cast<MPVInstance*>(instance);
    if (!mpv_instance->mpv) {
        die(env, "mpv is not created");
        return;
    }

    if (mpv_initialize(mpv_instance->mpv) < 0) {
        die(env, "mpv init failed");
        return;
    }

    mpv_instance->event_thread_request_exit = false;
    if (pthread_create(&mpv_instance->event_thread_id, nullptr, event_thread, mpv_instance) != 0) {
        die(env, "thread create failed");
        return;
    }
    pthread_setname_np(mpv_instance->event_thread_id, "event_thread");
}

jni_func(void, nativeDestroy, jlong instance) {
    auto mpv_instance = reinterpret_cast<MPVInstance*>(instance);
    if (!mpv_instance->mpv) {
        ALOGV("Cannot destroy mpv: mpv is not initialized");
        return;
    }

    mpv_instance->event_thread_request_exit = true;
    mpv_wakeup(mpv_instance->mpv);

    if (mpv_instance->event_thread_id != 0) {
        if (pthread_equal(pthread_self(), mpv_instance->event_thread_id)) {
            // destroy() was called by an EventObserver. Joining ourselves would
            // deadlock (and freeing immediately would be a use-after-free), so
            // let event_thread perform cleanup after this callback returns.
            mpv_instance->destroy_on_event_thread_exit = true;
            return;
        }
        pthread_join(mpv_instance->event_thread_id, nullptr);
        mpv_instance->event_thread_id = 0;
    }

    destroy_mpv_instance(env, mpv_instance);
}

jni_func(void, nativeCommand, jlong instance, jobjectArray jarray) {
    auto mpv_instance = reinterpret_cast<MPVInstance*>(instance);
    if (!mpv_instance->mpv) {
        ALOGE("Cannot run command: mpv is not initialized");
        return;
    }

    const char *arguments[128] = { nullptr };
    jstring stringRefs[128] = { nullptr };

    int len = env->GetArrayLength(jarray);

    if (len >= ARRAYLEN(arguments)) {
        ALOGE("Cannot run command: too many arguments");
        return;
    }

    for (int i = 0; i < len; ++i) {
        stringRefs[i] = (jstring)env->GetObjectArrayElement(jarray, i);
        arguments[i] = env->GetStringUTFChars(stringRefs[i], nullptr);
    }

    mpv_command(mpv_instance->mpv, arguments);

    for (int i = 0; i < len; ++i) {
        if (stringRefs[i]) {
            env->ReleaseStringUTFChars(stringRefs[i], arguments[i]);
            env->DeleteLocalRef(stringRefs[i]);
        }
    }
}

jni_func(jint, nativeRequestLogMessages, jlong instance, jstring jlevel) {
    auto mpv_instance = reinterpret_cast<MPVInstance*>(instance);
    if (!mpv_instance->mpv) {
        die(env, "mpv is not initialized");
        return 0;
    }

    const char *level = env->GetStringUTFChars(jlevel, nullptr);
    int result = mpv_request_log_messages(mpv_instance->mpv, level);
    env->ReleaseStringUTFChars(jlevel, level);

    return result;
}
