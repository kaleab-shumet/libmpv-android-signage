#pragma once

#include <atomic>
#include <pthread.h>
#include <jni.h>
#include <mpv/client.h>

// struct to hold the mpv_handle and other related data
struct MPVInstance {
    mpv_handle *mpv;
    JavaVM *vm;
    pthread_t event_thread_id;
    std::atomic<bool> event_thread_request_exit;
    std::atomic<bool> destroy_on_event_thread_exit;

    jobject javaObject;
    jobject appCtx;
    jobject surface;
};

// Terminates mpv and releases all JNI/global resources. The caller must ensure
// the event thread is no longer using the instance.
void destroy_mpv_instance(JNIEnv *env, MPVInstance *instance);
