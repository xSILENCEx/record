package com.llfbandit.record;

import android.media.MediaRecorder;
import android.os.Build;
import android.os.Handler;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;

interface Callable {
    void call(double param);
}

class VolumeChange implements Callable {
    private final MethodChannel channel;

    VolumeChange(MethodChannel channel) {
        this.channel = channel;
    }

    public void call(double volume) {
        if (channel != null)
            channel.invokeMethod("onVolumeChange", volume);
    }
}


class Recorder {
    private static final String LOG_TAG = "Record";

    private boolean isRecording = false;
    private boolean isPaused = false;
    private Callable onVolumeChange;

    private MediaRecorder recorder = null;

    Handler recordHandler = new Handler();
    private final Runnable mUpdateMicStatusTimer = new Runnable() {
        public void run() {
            if (isRecording) {
                double ratio = (double) recorder.getMaxAmplitude();
                double db = 0;
                if (ratio > 1) {
                    db = 20 * Math.log10(ratio);
                }
                onVolumeChange.call(db);
                recordHandler.postDelayed(mUpdateMicStatusTimer, 100);
            }
        }
    };

    ///开始捕捉音量
    private void startCatchVolume() {
        Log.d(LOG_TAG, "开始捕捉音量");
        recordHandler.postDelayed(mUpdateMicStatusTimer, 100);
    }

    ///停止捕捉音量
    private void stopCatchVolume() {
        Log.d(LOG_TAG, "停止捕捉音量");
        recordHandler.removeCallbacks(mUpdateMicStatusTimer);
    }

    void start(
            @NonNull String path,
            int encoder,
            int bitRate,
            double samplingRate,
            Callable onVolumeChange,
            @NonNull Result result
    ) {
        stopRecording();

        Log.d(LOG_TAG, "Start recording");

        recorder = new MediaRecorder();
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        recorder.setAudioEncodingBitRate(bitRate);
        recorder.setAudioSamplingRate((int) samplingRate);
        recorder.setOutputFormat(getOutputFormat(encoder));
        // must be set after output format
        recorder.setAudioEncoder(getEncoder(encoder));
        recorder.setOutputFile(path);

        try {
            recorder.prepare();
            recorder.start();
            isRecording = true;
            isPaused = false;
            this.onVolumeChange = onVolumeChange;
            startCatchVolume();
            result.success(null);
        } catch (Exception e) {
            recorder.release();
            recorder = null;
            result.error("-1", "Start recording failure", e.getMessage());
        }
    }

    void stop(@NonNull Result result) {
        stopRecording();
        result.success(null);
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    void pause(@NonNull Result result) {
        pauseRecording();
        result.success(null);
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    void resume(@NonNull Result result) {
        resumeRecording();
        result.success(null);
    }

    void isRecording(@NonNull Result result) {
        result.success(isRecording);
    }

    void isPaused(@NonNull Result result) {
        result.success(isPaused);
    }

    void close() {
        stopRecording();
    }

    private void stopRecording() {
        if (recorder != null) {
            try {
                if (isRecording || isPaused) {
                    Log.d(LOG_TAG, "Stop recording");
                    recorder.stop();
                }
            } catch (IllegalStateException ex) {
                // Mute this exception since 'isRecording' can't be 100% sure
            } finally {
                recorder.reset();
                recorder.release();
                recorder = null;
            }
        }

        isRecording = false;
        isPaused = false;
        stopCatchVolume();
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    private void pauseRecording() {
        if (recorder != null) {
            try {
                if (isRecording) {
                    Log.d(LOG_TAG, "Pause recording");
                    recorder.pause();
                    recordHandler.removeCallbacks(null);
                    isPaused = true;
                    stopCatchVolume();
                }
            } catch (IllegalStateException ex) {
                Log.d(LOG_TAG, "Did you call pause() before before start() or after stop()?\n" + ex.getMessage());
            }
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    private void resumeRecording() {
        if (recorder != null) {
            try {
                if (isPaused) {
                    Log.d(LOG_TAG, "Resume recording");
                    recorder.resume();
                    isPaused = false;
                    startCatchVolume();
                }
            } catch (IllegalStateException ex) {
                Log.d(LOG_TAG, "Did you call resume() before before start() or after stop()?\n" + ex.getMessage());
            }
        }
    }

    private int getOutputFormat(int encoder) {
        if (encoder == 3 || encoder == 4) {
            return MediaRecorder.OutputFormat.THREE_GPP;
        } else if (encoder == 6) {
            return MediaRecorder.OutputFormat.AAC_ADTS;
        }

        return MediaRecorder.OutputFormat.MPEG_4;
    }

    // https://developer.android.com/reference/android/media/MediaRecorder.AudioEncoder
    private int getEncoder(int encoder) {
        switch (encoder) {
            case 1:
                return MediaRecorder.AudioEncoder.AAC_ELD;
            case 2:
                return MediaRecorder.AudioEncoder.HE_AAC;
            case 3:
                return MediaRecorder.AudioEncoder.AMR_NB;
            case 4:
                return MediaRecorder.AudioEncoder.AMR_WB;
            case 5:
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    return MediaRecorder.AudioEncoder.OPUS;
                } else {
                    Log.d(LOG_TAG, "OPUS codec is available starting from API 29.\nFalling back to AAC");
                }
            default:
                return MediaRecorder.AudioEncoder.AAC;
        }
    }
}
