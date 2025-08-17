#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

# 設定環境
use YourApp::API::Upload;
use Dancer2;

print "=" x 60 . "\n";
print "🚀 啟動 CSV 上傳 API 伺服器\n";
print "=" x 60 . "\n";

# 讀取設定
my $config = config();
my $host   = $config->{host} || '127.0.0.1';
my $port   = $config->{port} || 5120;

print "📍 伺服器位址: http://$host:$port\n";
print "🔗 API 端點:\n";
print "   POST http://$host:$port/api/v1/upload/add_shop\n";
print "   GET  http://$host:$port/api/v1/upload/status/{process_id}\n";
print "📁 工作目錄: " . $FindBin::Bin . "\n";
print "⏰ 啟動時間: " . scalar(localtime) . "\n";
print "=" x 60 . "\n";

# 初始化資料庫 (如果使用 PostgreSQL)
init_database() if $config->{plugins}->{Database}->{driver} eq 'Pg';

print "✅ 伺服器已啟動，按 Ctrl+C 停止\n\n";

# 啟動伺服器
dance;

# 初始化資料庫函數
sub init_database {
    my $db_config = config->{plugins}->{Database};

    print "🗄️  初始化 PostgreSQL 資料庫: $db_config->{database}\n";

    # 建立資料表的 SQL (PostgreSQL 語法)
    my $sql = q{
        CREATE TABLE IF NOT EXISTS processing_jobs (
            id SERIAL PRIMARY KEY,
            process_id VARCHAR(50) UNIQUE NOT NULL,
            status VARCHAR(20) NOT NULL,
            progress VARCHAR(10),
            shop_id INTEGER,
            version INTEGER DEFAULT 4,
            regional_count INTEGER,
            regional_ids TEXT,
            messages TEXT,
            current_messages TEXT,
            error_messages TEXT,
            error_count INTEGER DEFAULT 0,
            validation_details TEXT,
            csv_content TEXT,
            analysis TEXT,
            auth_token TEXT,
            filename TEXT,
            estimated_completion TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP,
            completed_at TIMESTAMP
        );
        
        CREATE INDEX IF NOT EXISTS idx_process_id ON processing_jobs(process_id);
        CREATE INDEX IF NOT EXISTS idx_status ON processing_jobs(status);
        CREATE INDEX IF NOT EXISTS idx_created_at ON processing_jobs(created_at);
    };

    # 執行 SQL
    use DBI;
    my $dsn = "dbi:Pg:dbname=$db_config->{database};host=$db_config->{host};port=$db_config->{port}";

    eval {
        my $dbh = DBI->connect(
            $dsn,
            $db_config->{username},
            $db_config->{password},
            {
                RaiseError     => 1,
                AutoCommit     => 1,
                pg_enable_utf8 => 1
            }
        );

        # 執行建表 SQL
        for my $statement ( split /;/, $sql ) {
            $statement =~ s/^\s+|\s+$//g;    # 去除前後空白
            next unless $statement;
            $dbh->do($statement);
        }

        $dbh->disconnect;
        print "✅ PostgreSQL 資料庫初始化完成\n";
    };

    if ($@) {
        print "❌ 資料庫初始化失敗: $@\n";
        print "請確認：\n";
        print "  1. PostgreSQL 服務已啟動\n";
        print "  2. 資料庫 '$db_config->{database}' 已建立\n";
        print "  3. 用戶 '$db_config->{username}' 有適當權限\n";
        print "  4. 連線參數正確\n\n";
        print "建立資料庫指令：\n";
        print "  createdb -U postgres $db_config->{database}\n";
        print "  psql -U postgres -c \"CREATE USER $db_config->{username} WITH PASSWORD '$db_config->{password}';\"\n";
        print
"  psql -U postgres -c \"GRANT ALL PRIVILEGES ON DATABASE $db_config->{database} TO $db_config->{username};\"\n";
    }
}
