#include <jni.h>

#include <mpv/client.h>

#include "jni_utils.h"
#include "log.h"
#include "globals.h"

extern "C" {
    jni_func(void, nativeAttachSurface, jlong instance, jobject surface);
    jni_func(void, nativeDetachSurface, jlong instance);
}

jni_func(void, nativeAttachSurface, jlong instance, jobject surface) {
    auto mpv_instance = reinterpret_cast<MPVInstance*>(instance);

    jobject new_surface = env->NewGlobalRef(surface);
    if (!new_surface) {
        die(env, "invalid surface provided");
        return;
    }

    int64_t wid = reinterpret_cast<intptr_t>(new_surface);
    int result = mpv_set_option(mpv_instance->mpv, "wid", MPV_FORMAT_INT64, &wid);
    if (result < 0) {
        ALOGE("mpv_set_option(wid) returned error %s", mpv_error_string(result));
        env->DeleteGlobalRef(new_surface);
        return;
    }

    if (mpv_instance->surface)
        env->DeleteGlobalRef(mpv_instance->surface);
    mpv_instance->surface = new_surface;
}

jni_func(void, nativeDetachSurface, jlong instance) {
    auto mpv_instance = reinterpret_cast<MPVInstance*>(instance);
    int64_t wid = 0;
    int result = mpv_set_option(mpv_instance->mpv, "wid", MPV_FORMAT_INT64, &wid);
    if (result < 0)
        ALOGE("mpv_set_option(wid) returned error %s", mpv_error_string(result));

    if (mpv_instance->surface) {
        env->DeleteGlobalRef(mpv_instance->surface);
        mpv_instance->surface = nullptr;
    }
}
