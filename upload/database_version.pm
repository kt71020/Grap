#!/usr/bin/perl
package YourApp::API::Upload::Database;

use strict;
use warnings;
use utf8;
use Dancer2;
use Dancer2::Plugin::Database;
use JSON;
use DateTime;

# 設定資料庫 - 在 config.yml 中設定
# database:
#   driver: 'SQLite'
#   database: 'upload_jobs.db'
#   on_connect_do: ["PRAGMA foreign_keys = ON"]

#=============================================================================
# 資料庫操作函數
#=============================================================================

# 建立處理工作 (資料庫版本)
sub create_processing_job_db {
    my ( $process_id, $job_data ) = @_;

    database->quick_insert(
        'processing_jobs',
        {
            process_id       => $process_id,
            status           => 'processing',
            progress         => '0%',
            created_at       => DateTime->now->strftime('%Y-%m-%d %H:%M:%S'),
            updated_at       => DateTime->now->strftime('%Y-%m-%d %H:%M:%S'),
            current_messages => encode_json( ['初始化處理程序...'] ),
            csv_content      => encode_json( $job_data->{csv_content} ),
            analysis         => encode_json( $job_data->{analysis} ),
            auth_token       => $job_data->{auth_token},
            filename         => $job_data->{filename}
        }
    );

    debug "Created processing job in database: $process_id";
}

# 取得工作狀態 (資料庫版本)
sub get_job_status_db {
    my ($process_id) = @_;

    my $job = database->quick_select(
        'processing_jobs',
        {
            process_id => $process_id
        }
    );

    return unless $job;

    # 根據狀態回傳不同格式
    if ( $job->{status} eq 'completed' ) {
        return {
            status             => 1,                 # 完成
            sid                => $job->{shop_id},
            version            => $job->{version}        || 4,
            rows_regional      => $job->{regional_count} || 0,
            regional_id_list   => decode_json( $job->{regional_ids} || '[]' ),
            message            => decode_json( $job->{messages}     || '["處理完成"]' ),
            error              => 0,
            validation_details => decode_json( $job->{validation_details} || '{}' ),
            csv_content_list   => decode_json( $job->{csv_content}        || '[]' )
        };
    }
    elsif ( $job->{status} eq 'processing' ) {
        return {
            status         => 2,                                                           # 處理中
            process_id     => $process_id,
            progress       => $job->{progress} || "0%",
            message        => decode_json( $job->{current_messages} || '["正在處理中..."]' ),
            estimated_time => $job->{estimated_completion},
            error          => 0
        };
    }
    elsif ( $job->{status} eq 'failed' ) {
        return {
            status     => 0,                                                               # 失敗
            process_id => $process_id,
            message    => decode_json( $job->{error_messages} || '["處理失敗"]' ),
            error      => $job->{error_count} || 1
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

# 更新工作狀態 (資料庫版本)
sub update_job_status_db {
    my ( $process_id, $updates ) = @_;

    # 轉換陣列為 JSON
    for my $key ( keys %$updates ) {
        if ( ref $updates->{$key} eq 'ARRAY' ) {
            $updates->{$key} = encode_json( $updates->{$key} );
        }
    }

    $updates->{updated_at} = DateTime->now->strftime('%Y-%m-%d %H:%M:%S');

    database->quick_update( 'processing_jobs', { process_id => $process_id }, $updates );

    debug "Updated job status in database for $process_id";
}

# 清理過期工作 (資料庫版本)
sub cleanup_expired_jobs_db {
    my $cutoff = DateTime->now->subtract( days => 7 )->strftime('%Y-%m-%d %H:%M:%S');

    my $deleted = database->do( 'DELETE FROM processing_jobs WHERE created_at < ?', {}, $cutoff );

    debug "Cleaned up $deleted expired jobs from database";
}

1;

__END__

=head1 PostgreSQL SCHEMA

CREATE TABLE processing_jobs (
    id SERIAL PRIMARY KEY,
    process_id VARCHAR(50) UNIQUE NOT NULL,
    status VARCHAR(20) NOT NULL, -- 'processing', 'completed', 'failed'
    progress VARCHAR(10), -- '50%'
    shop_id INTEGER,
    version INTEGER DEFAULT 4,
    regional_count INTEGER,
    regional_ids TEXT, -- JSON array
    messages TEXT, -- JSON array
    current_messages TEXT, -- JSON array for current status
    error_messages TEXT, -- JSON array
    error_count INTEGER DEFAULT 0,
    validation_details TEXT, -- JSON object
    csv_content TEXT, -- JSON array
    analysis TEXT, -- JSON object
    auth_token TEXT,
    filename TEXT,
    estimated_completion TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX idx_process_id ON processing_jobs(process_id);
CREATE INDEX idx_status ON processing_jobs(status);
CREATE INDEX idx_created_at ON processing_jobs(created_at);

-- 建立資料庫和用戶
-- createdb -U postgres upload_db
-- psql -U postgres -c "CREATE USER upload_user WITH PASSWORD 'upload_password';"
-- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE upload_db TO upload_user;"

=cut
