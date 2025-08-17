#!/usr/bin/perl
package YourApp::API::Upload;

use strict;
use warnings;
use utf8;
use Dancer2;
use JSON;
use DateTime;
use File::Temp  qw(tempfile);
use POSIX       qw(fork waitpid WNOHANG);
use Time::HiRes qw(sleep);

# 設定 JSON 編碼
set serializer => 'JSON';
set charset    => 'UTF-8';

# API 前綴
prefix '/api/v1/upload';

# 全域變數
our $job_storage = {};    # 簡單的記憶體儲存，生產環境建議用資料庫或 Redis

#=============================================================================
# 狀態查詢端點
#=============================================================================
get '/status/:process_id' => sub {
    my $process_id = route_parameters->get('process_id');

    # 驗證認證
    my $auth_token = request->header('Authorization');
    unless ($auth_token) {
        status 401;
        return {
            status  => 0,
            message => ['認證失敗：缺少 Authorization header'],
            error   => 1
        };
    }

    # 驗證 process_id 格式
    unless ( $process_id && $process_id =~ /^\d+_\d+$/ ) {
        status 400;
        return {
            status  => 0,
            message => ['無效的處理 ID 格式'],
            error   => 1
        };
    }

    # 取得處理狀態
    my $job_status = get_job_status($process_id);

    unless ($job_status) {
        status 404;
        return {
            status     => 0,
            message    => ["找不到處理 ID: $process_id"],
            error      => 1,
            process_id => $process_id
        };
    }

    # 回傳狀態資訊
    return $job_status;
};

#=============================================================================
# 上傳端點
#=============================================================================
post '/add_shop' => sub {
    my $upload = request->upload('file');

    # 驗證上傳檔案
    unless ($upload) {
        status 400;
        return {
            status  => 0,
            message => ['缺少上傳檔案'],
            error   => 1
        };
    }

    # 驗證認證
    my $auth_token = request->header('Authorization');
    unless ($auth_token) {
        status 401;
        return {
            status  => 0,
            message => ['認證失敗：缺少 Authorization header'],
            error   => 1
        };
    }

    # 驗證檔案類型
    unless ( $upload->filename =~ /\.csv$/i ) {
        status 400;
        return {
            status  => 0,
            message => ['檔案必須是 CSV 格式'],
            error   => 1
        };
    }

    # 讀取 CSV 內容
    my $csv_content = $upload->content;
    my @lines       = split /\r?\n/, $csv_content;

    # 基本驗證
    if ( @lines < 5 ) {
        status 400;
        return {
            status  => 0,
            message => ['CSV 檔案內容太少，請檢查格式'],
            error   => 1
        };
    }

    # 分析資料量
    my $analysis = analyze_csv_content( \@lines );

    # 決定處理方式：分公司數量超過 50 筆或總行數超過 500 行使用非同步
    if ( $analysis->{regional_count} > 50 || @lines > 500 ) {

        # 產生處理 ID
        my $process_id = generate_process_id();

        # 建立處理工作
        create_processing_job(
            $process_id,
            {
                csv_content => \@lines,
                analysis    => $analysis,
                auth_token  => $auth_token,
                filename    => $upload->filename
            }
        );

        # 啟動背景處理
        start_background_processing($process_id);

        # 立即回傳處理中狀態
        return {
            status     => 2,             # 處理中
            process_id => $process_id,
            message    => [
                "偵測到大量資料需要處理",
                "分公司資料：$analysis->{regional_count} 筆",
                "商品資料：$analysis->{product_count} 筆",
                "已啟動背景處理程序",
                "請使用狀態查詢 API 追蹤處理進度"
            ],
            estimated_time     => estimate_processing_time($analysis),
            progress           => "0%",
            error              => 0,
            validation_details => {
                shop_info_count         => $analysis->{shop_info_count},
                product_count           => $analysis->{product_count},
                category_count          => $analysis->{category_count},
                shop_option_count       => $analysis->{option_count},
                shop_option_value_count => $analysis->{option_value_count},
                regional_count          => $analysis->{regional_count}
            }
        };
    }
    else {
        # 小量資料直接同步處理
        return process_csv_sync( \@lines, $analysis );
    }
};

#=============================================================================
# 核心處理函數
#=============================================================================

# 分析 CSV 內容
sub analyze_csv_content {
    my ($lines) = @_;

    my $analysis = {
        shop_info_count    => 0,
        product_count      => 0,
        category_count     => 0,
        option_count       => 0,
        option_value_count => 0,
        regional_count     => 0
    };

    my $current_section = '';

    for my $line (@$lines) {
        next unless $line;

        if ( $line =~ /---,分隔線,(.+?),?---/ ) {
            $current_section = $1;
            next;
        }

        # 跳過標題行
        next if $line =~ /^(商品分類編號|選項編號|分公司名稱|申請編號)/;

        if ( $current_section eq '商店資訊' ) {
            $analysis->{shop_info_count}++ if $line =~ /^[^,]+,/;
        }
        elsif ( $current_section eq '商品分類代碼' ) {
            $analysis->{category_count}++ if $line =~ /^\d+,/;
        }
        elsif ( $current_section eq '共用選項代碼' ) {
            $analysis->{option_count}++ if $line =~ /^\d+,/;
        }
        elsif ( $current_section eq '共用選項價格代碼' ) {
            $analysis->{option_value_count}++ if $line =~ /^\d+,/;
        }
        elsif ( $current_section eq '商品資料' ) {
            $analysis->{product_count}++ if $line =~ /^\d+,/;
        }
        elsif ( $current_section eq '分公司基本資料' ) {
            $analysis->{regional_count}++ if $line =~ /^[^,]+,\d/;
        }
    }

    return $analysis;
}

# 同步處理 CSV
sub process_csv_sync {
    my ( $lines, $analysis ) = @_;

    # 模擬處理邏輯 - 這裡你要替換成實際的處理程式碼
    my $shop_id = int( rand(9000) ) + 1000;    # 模擬商店 ID

    # 模擬分公司 ID 列表
    my @regional_ids = ();
    for ( 1 .. $analysis->{regional_count} ) {
        push @regional_ids, int( rand(9000) ) + 2000;
    }

    return {
        status             => 1,
        sid                => $shop_id,
        version            => 4,
        rows_regional      => $analysis->{regional_count},
        regional_id_list   => \@regional_ids,
        message            => [ "商店資料已存在，商店資料編號: $shop_id", "有分公司資料需要新增", "分公司資料處理完成", "商店與商品資料已成功上傳" ],
        error              => 0,
        validation_details => {
            shop_info_count         => $analysis->{shop_info_count},
            product_count           => $analysis->{product_count},
            category_count          => $analysis->{category_count},
            shop_option_count       => $analysis->{option_count},
            shop_option_value_count => $analysis->{option_value_count},
            regional_count          => $analysis->{regional_count}
        },
        csv_content_list => $lines    # 如果需要的話
    };
}

# 建立處理工作
sub create_processing_job {
    my ( $process_id, $job_data ) = @_;

    $job_storage->{$process_id} = {
        process_id       => $process_id,
        status           => 'processing',
        progress         => '0%',
        created_at       => DateTime->now,
        updated_at       => DateTime->now,
        current_messages => ['初始化處理程序...'],
        csv_content      => $job_data->{csv_content},
        analysis         => $job_data->{analysis},
        auth_token       => $job_data->{auth_token},
        filename         => $job_data->{filename},
        pid              => undef                       # 將儲存子程序 PID
    };

    debug "Created processing job: $process_id";
}

# 啟動背景處理
sub start_background_processing {
    my ($process_id) = @_;

    my $pid = fork();

    if ( !defined $pid ) {
        error "無法建立子程序: $!";
        update_job_status(
            $process_id,
            {
                status         => 'failed',
                error_messages => ["系統錯誤：無法啟動背景處理"],
                error_count    => 1
            }
        );
        return;
    }

    if ( $pid == 0 ) {

        # 子程序
        process_csv_async($process_id);
        exit 0;
    }
    else {
        # 父程序
        $job_storage->{$process_id}->{pid} = $pid;
        debug "Started background processing: PID $pid for job $process_id";
    }
}

# 非同步處理函數
sub process_csv_async {
    my ($process_id) = @_;

    my $job = $job_storage->{$process_id};
    return unless $job;

    eval {
        my $lines    = $job->{csv_content};
        my $analysis = $job->{analysis};

        # 階段 1: 解析 CSV (10%)
        update_job_status(
            $process_id,
            {
                progress         => '10%',
                current_messages => ['正在解析 CSV 檔案結構...']
            }
        );
        sleep(1);    # 模擬處理時間

        # 階段 2: 處理商店資訊 (30%)
        update_job_status(
            $process_id,
            {
                progress         => '30%',
                current_messages => ['正在處理商店基本資訊...']
            }
        );

        my $shop_id = process_shop_info($lines);
        sleep(2);    # 模擬處理時間

        # 階段 3: 處理商品分類 (50%)
        update_job_status(
            $process_id,
            {
                progress         => '50%',
                current_messages => ['正在處理商品分類資料...']
            }
        );

        process_categories($lines);
        sleep(1);

        # 階段 4: 處理商品資料 (70%)
        update_job_status(
            $process_id,
            {
                progress         => '70%',
                current_messages => ['正在處理商品資料...']
            }
        );

        process_products($lines);
        sleep(2);

        # 階段 5: 處理分公司資料 (90%) - 最耗時的部分
        update_job_status(
            $process_id,
            {
                progress         => '90%',
                current_messages => [ '正在處理分公司資料...', "預計處理 $analysis->{regional_count} 筆分公司資料" ]
            }
        );

        my $regional_result = process_regional_data_with_progress( $process_id, $lines, $analysis );

        # 階段 6: 完成 (100%)
        update_job_status(
            $process_id,
            {
                status             => 'completed',
                progress           => '100%',
                completed_at       => DateTime->now,
                shop_id            => $shop_id,
                regional_count     => $regional_result->{count},
                regional_ids       => $regional_result->{ids},
                messages           => [ "商店資料已存在，商店資料編號: $shop_id", '有分公司資料需要新增', '分公司資料處理完成', '商店與商品資料已成功上傳' ],
                validation_details => {
                    shop_info_count         => $analysis->{shop_info_count},
                    product_count           => $analysis->{product_count},
                    category_count          => $analysis->{category_count},
                    shop_option_count       => $analysis->{option_count},
                    shop_option_value_count => $analysis->{option_value_count},
                    regional_count          => $analysis->{regional_count}
                }
            }
        );

        debug "Processing completed for job: $process_id";

    };

    if ($@) {
        error "Processing failed for job $process_id: $@";
        update_job_status(
            $process_id,
            {
                status         => 'failed',
                error_messages => ["處理失敗: $@"],
                error_count    => 1
            }
        );
    }
}

# 處理分公司資料並顯示進度
sub process_regional_data_with_progress {
    my ( $process_id, $lines, $analysis ) = @_;

    my @regional_ids = ();
    my $processed    = 0;
    my $total        = $analysis->{regional_count};

    # 模擬逐筆處理分公司資料
    for ( 1 .. $total ) {

        # 模擬每筆分公司資料的處理時間
        sleep(0.1);    # 每筆 0.1 秒

        $processed++;
        my $regional_id = int( rand(9000) ) + 2000;
        push @regional_ids, $regional_id;

        # 每處理 10 筆或最後一筆時更新進度
        if ( $processed % 10 == 0 || $processed == $total ) {
            my $percent = int( 90 + ( $processed / $total ) * 10 );    # 90% 到 100%
            update_job_status(
                $process_id,
                {
                    progress         => "${percent}%",
                    current_messages => [ "正在處理分公司資料... ($processed/$total)", "最新處理的分公司 ID: $regional_id" ]
                }
            );
        }
    }

    return {
        count => scalar(@regional_ids),
        ids   => \@regional_ids
    };
}

# 模擬處理函數
sub process_shop_info {
    my ($lines) = @_;
    return int( rand(9000) ) + 1000;    # 模擬商店 ID
}

sub process_categories {
    my ($lines) = @_;

    # 模擬處理分類
    return 1;
}

sub process_products {
    my ($lines) = @_;

    # 模擬處理商品
    return 1;
}

# 取得工作狀態
sub get_job_status {
    my ($process_id) = @_;

    my $job = $job_storage->{$process_id};
    return unless $job;

    # 檢查子程序是否還在執行
    if ( $job->{pid} && $job->{status} eq 'processing' ) {
        my $result = waitpid( $job->{pid}, WNOHANG );
        if ( $result > 0 ) {

            # 子程序已結束，但狀態可能還沒更新
            debug "Child process $job->{pid} has ended";
        }
    }

    # 根據狀態回傳不同格式
    if ( $job->{status} eq 'completed' ) {
        return {
            status             => 1,                 # 完成
            sid                => $job->{shop_id},
            version            => 4,
            rows_regional      => $job->{regional_count} || 0,
            regional_id_list   => $job->{regional_ids}   || [],
            message            => $job->{messages}       || ["處理完成"],
            error              => 0,
            validation_details => $job->{validation_details} || {}
        };
    }
    elsif ( $job->{status} eq 'processing' ) {
        return {
            status         => 2,                     # 處理中
            process_id     => $process_id,
            progress       => $job->{progress}         || "0%",
            message        => $job->{current_messages} || ["正在處理中..."],
            estimated_time => estimate_remaining_time($job),
            error          => 0
        };
    }
    elsif ( $job->{status} eq 'failed' ) {
        return {
            status     => 0,                         # 失敗
            process_id => $process_id,
            message    => $job->{error_messages} || ["處理失敗"],
            error      => $job->{error_count}    || 1
        };
    }

    # 預設回傳
    return {
        status     => 2,
        process_id => $process_id,
        message    => ['狀態未知'],
        error      => 0
    };
}

# 更新工作狀態
sub update_job_status {
    my ( $process_id, $updates ) = @_;

    return unless $job_storage->{$process_id};

    $updates->{updated_at} = DateTime->now;

    for my $key ( keys %$updates ) {
        $job_storage->{$process_id}->{$key} = $updates->{$key};
    }

    debug "Updated job status for $process_id: " . to_json($updates);
}

# 產生處理 ID
sub generate_process_id {
    return time() . '_' . int( rand(10000) );
}

# 估算處理時間
sub estimate_processing_time {
    my ($analysis) = @_;

    # 基礎時間 + 分公司數量 * 0.2 秒 + 商品數量 * 0.1 秒
    my $estimated_seconds = 10 + ( $analysis->{regional_count} * 0.2 ) + ( $analysis->{product_count} * 0.1 );

    return format_duration($estimated_seconds);
}

# 估算剩餘時間
sub estimate_remaining_time {
    my ($job) = @_;

    my $progress = $job->{progress} || "0%";
    $progress =~ s/%//;
    $progress = int($progress);

    return "未知" if $progress <= 0;

    my $elapsed         = time() - $job->{created_at}->epoch;
    my $total_estimated = ( $elapsed / $progress ) * 100;
    my $remaining       = $total_estimated - $elapsed;

    return format_duration($remaining);
}

# 格式化時間
sub format_duration {
    my ($seconds) = @_;

    return "未知" unless defined $seconds && $seconds > 0;

    if ( $seconds < 60 ) {
        return sprintf( "%.0f 秒", $seconds );
    }
    elsif ( $seconds < 3600 ) {
        return sprintf( "%.1f 分鐘", $seconds / 60 );
    }
    else {
        return sprintf( "%.1f 小時", $seconds / 3600 );
    }
}

#=============================================================================
# 清理過期工作 (可選)
#=============================================================================
sub cleanup_expired_jobs {
    my $cutoff = DateTime->now->subtract( hours => 24 );

    for my $process_id ( keys %$job_storage ) {
        my $job = $job_storage->{$process_id};
        if ( $job->{created_at} < $cutoff ) {
            delete $job_storage->{$process_id};
            debug "Cleaned up expired job: $process_id";
        }
    }
}

# 定期清理 (在生產環境中，你可能想用 cron 或其他方式)
hook before_request => sub {

    # 1% 的機率執行清理
    cleanup_expired_jobs() if rand() < 0.01;
};

1;

__END__

=head1 NAME

YourApp::API::Upload - 非同步 CSV 上傳處理 API

=head1 DESCRIPTION

這個模組提供非同步的 CSV 檔案上傳和處理功能，適用於大量資料的處理場景。

=head1 API ENDPOINTS

=head2 POST /api/v1/upload/add_shop

上傳 CSV 檔案進行處理。

=head2 GET /api/v1/upload/status/:process_id

查詢處理狀態。

=head1 AUTHOR

Your Name

=cut
