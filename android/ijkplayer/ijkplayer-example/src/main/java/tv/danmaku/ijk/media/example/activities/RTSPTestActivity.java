/*
 * RTSPTestActivity.java
 * RTSP 录像测试页面 - 播放、快照、录像功能
 */

package tv.danmaku.ijk.media.example.activities;

import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.media.MediaScannerConnection;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import java.io.File;
import java.io.FileOutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

import tv.danmaku.ijk.media.example.R;
import tv.danmaku.ijk.media.example.widget.media.IRenderView;
import tv.danmaku.ijk.media.example.widget.media.IjkVideoView;
import tv.danmaku.ijk.media.player.IMediaPlayer;
import tv.danmaku.ijk.media.player.IjkMediaPlayer;

public class RTSPTestActivity extends AppCompatActivity {
    private static final String TAG = "RTSPTestActivity";
    
    // RTSP 地址
    private static final String RTSP_URL = "rtsp://192.168.1.1:7070/webcam";
    
    private IjkVideoView mVideoView;
    private TextView mStatusTextView;
    private ImageView mSnapshotImageView;
    private Button mRecordButton;
    
    private boolean mIsRecording = false;
    private String mRecordingPath;

    public static Intent newIntent(Context context) {
        return new Intent(context, RTSPTestActivity.class);
    }

    public static void intentTo(Context context) {
        context.startActivity(newIntent(context));
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_rtsp_test);
        
        initViews();
        setupPlayer();
        setupListeners();
    }

    private void initViews() {
        mVideoView = findViewById(R.id.video_view);
        mStatusTextView = findViewById(R.id.tv_status);
        mSnapshotImageView = findViewById(R.id.iv_snapshot);
        mRecordButton = findViewById(R.id.btn_record);
    }

    private void setupPlayer() {
        // 加载 native 库
        IjkMediaPlayer.loadLibrariesOnce(null);
        IjkMediaPlayer.native_profileBegin("libijkplayer.so");
        
        // 配置低延迟 RTSP 播放参数
        mVideoView.setOnPlayerOptionsListener(ijkMediaPlayer -> {
            // 设置 overlay-format 为 YV12，兼容 MJPEG 的 yuvj422p 格式
            // YV12 = 0x32315659 (SDL_FCC_YV12)
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "overlay-format", IjkMediaPlayer.SDL_FCC_RV16);
            // 设置最长分析时长，减少探测流信息的时间（单位微秒）
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzemaxduration", 100);
            // 设置读取数据包的最大缓冲区大小。对于低延迟，设小一点
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "probesize", 7168);
            // 强制无缓存播放
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", 0);
            // 启用实时模式
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "infbuf", 1);
            // 启用丢帧
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "framedrop", 1);
            // 减少等待开始播放的时间
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 1);

            // 你之前的这个配置可能会导致额外的处理开销
            ijkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "video-need-transcoding", 0); // 除非确有必要，否则关闭转码
        });
        
        // 设置播放器监听
        mVideoView.setOnPreparedListener(mp -> {
            mStatusTextView.setText("▶️ 正在播放");
            Log.d(TAG, "Player prepared");
            // 因为 start-on-prepared=0，需要手动调用 start()

        });
        
        mVideoView.setOnErrorListener((mp, what, extra) -> {
            mStatusTextView.setText("❌ 播放错误: " + what);
            Log.e(TAG, "Player error: what=" + what + ", extra=" + extra);
            return true;
        });
        
        mVideoView.setOnInfoListener((mp, what, extra) -> {
            if (what == IMediaPlayer.MEDIA_INFO_BUFFERING_START) {
                mStatusTextView.setText("⏳ 缓冲中...");
            } else if (what == IMediaPlayer.MEDIA_INFO_BUFFERING_END) {
                mStatusTextView.setText("▶️ 正在播放");
            } else if (what == IMediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START) {
                mStatusTextView.setText("▶️ 正在播放");
            }
            return false;
        });
        
        // 设置 TextureRenderView 以支持旋转功能 (SurfaceRenderView 不支持旋转)
        mVideoView.setRender(IjkVideoView.RENDER_TEXTURE_VIEW);
        
        // 设置视频路径
        mVideoView.setVideoPath(RTSP_URL);
        mVideoView.start();
    }

    private void setupListeners() {
        // 关闭按钮
        findViewById(R.id.btn_close).setOnClickListener(v -> finish());
        
        // 快照按钮
        findViewById(R.id.btn_snapshot).setOnClickListener(v -> takeSnapshot());
        
        // 录像按钮
        mRecordButton.setOnClickListener(v -> toggleRecording());
        
        // 旋转按钮
        findViewById(R.id.btn_rotate).setOnClickListener(v -> rotateVideo());
    }

    /**
     * 旋转视频，循环切换 0 -> 90 -> 180 -> 270 -> 0
     * 横屏(0°/180°)时全屏显示，竖屏(90°/270°)时自适应
     */
    private void rotateVideo() {
        int currentRotation = mVideoView.getVideoRotation();
        int newRotation = (currentRotation + 90) % 360;
        mVideoView.setVideoRotation(newRotation);
        
        // 根据旋转角度调整画面显示模式
        // 0° 或 180° 是横屏 -> 全屏填充
        // 90° 或 270° 是竖屏 -> 自适应
        if (newRotation == 0 || newRotation == 180) {
            // 横屏：全屏填充
            mVideoView.setAspectRatio(IRenderView.AR_MATCH_PARENT);
            mStatusTextView.setText("🔄 旋转: " + newRotation + "° (全屏)");
        } else {
            // 竖屏：自适应
            mVideoView.setAspectRatio(IRenderView.AR_4_3_FIT_PARENT);
            mStatusTextView.setText("🔄 旋转: " + newRotation + "° (自适应)");
        }
    }

    private void takeSnapshot() {
        Bitmap bitmap = mVideoView.getBitmap();
        if (bitmap != null) {
            mSnapshotImageView.setImageBitmap(bitmap);
            mSnapshotImageView.setVisibility(View.VISIBLE);
            
            // 保存到相册
            saveImageToGallery(bitmap);
            mStatusTextView.setText("✅ 快照成功");
        } else {
            mStatusTextView.setText("❌ 快照失败");
        }
    }

    private void saveImageToGallery(Bitmap bitmap) {
        try {
            File picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
            File ijkDir = new File(picturesDir, "IJKPlayer");
            if (!ijkDir.exists()) {
                ijkDir.mkdirs();
            }
            
            String filename = "snapshot_" + new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date()) + ".jpg";
            File file = new File(ijkDir, filename);
            
            FileOutputStream fos = new FileOutputStream(file);
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, fos);
            fos.close();
            
            // 通知相册更新
            MediaScannerConnection.scanFile(this, new String[]{file.getAbsolutePath()}, null, null);
            
            Toast.makeText(this, "已保存到相册", Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Log.e(TAG, "Save snapshot failed", e);
            Toast.makeText(this, "保存失败", Toast.LENGTH_SHORT).show();
        }
    }

    private void toggleRecording() {
        if (!mIsRecording) {
            // 开始录像
            File moviesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES);
            File ijkDir = new File(moviesDir, "IJKPlayer");
            if (!ijkDir.exists()) {
                ijkDir.mkdirs();
            }
            
            String filename = "record_" + new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date()) + ".mp4";
            mRecordingPath = new File(ijkDir, filename).getAbsolutePath();
            
            int result = mVideoView.startRecording(mRecordingPath);
            if (result == 0) {
                mIsRecording = true;
                mRecordButton.setText("⏹ 停止");
                mStatusTextView.setText("🔴 录像中...");
            } else {
                mStatusTextView.setText("❌ 开始录像失败");
            }
        } else {
            // 停止录像
            int result = mVideoView.stopRecording();
            if (result == 0) {
                mIsRecording = false;
                mRecordButton.setText("🔴 录像");
                mStatusTextView.setText("✅ 已保存录像");
                
                // 通知相册更新
                MediaScannerConnection.scanFile(this, new String[]{mRecordingPath}, null, null);
                Toast.makeText(this, "录像已保存", Toast.LENGTH_SHORT).show();
            } else {
                mStatusTextView.setText("❌ 停止录像失败");
            }
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        
        if (mIsRecording) {
            mVideoView.stopRecording();
        }
        
        mVideoView.stopPlayback();
        mVideoView.release(true);
        IjkMediaPlayer.native_profileEnd();
    }
}
