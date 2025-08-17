#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use DBI;
use FindBin;
use lib "$FindBin::Bin/../../lib";

# 設定輸出編碼
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

# 讀取設定檔
use YAML::Tiny;

print "🐘 PostgreSQL 資料庫初始化工具\n";
print "=" x 50 . "\n";

# 讀取設定
my $config_file = "config.yml";
unless ( -f $config_file ) {
    die "❌ 找不到設定檔: $config_file\n";
}

my $yaml      = YAML::Tiny->read($config_file);
my $config    = $yaml->[0];
my $db_config = $config->{plugins}->{Database};

unless ( $db_config && $db_config->{driver} eq 'Pg' ) {
    die "❌ 設定檔中未找到 PostgreSQL 設定\n";
}
$db_config->{host}     = 'amelia.uirapuka.com';
$db_config->{port}     = '5432';
$db_config->{username} = 'kt';
$db_config->{password} = 'b1uxcdq';
$db_config->{database} = 'Bailey';

print "📋 資料庫設定:\n";
print "   主機: $db_config->{host}:$db_config->{port}\n";
print "   資料庫: $db_config->{database}\n";
print "   用戶: $db_config->{username}\n";

# 建立連線
my $dsn = "dbi:Pg:dbname=$db_config->{database};host=$db_config->{host};port=$db_config->{port}";

print "\n🔗 嘗試連線到 PostgreSQL...\n";

my $dbh;
eval {
    $dbh = DBI->connect(
        $dsn,
        $db_config->{username},
        $db_config->{password},
        {
            RaiseError     => 1,
            AutoCommit     => 1,
            pg_enable_utf8 => 1
        }
    );
    print "✅ 資料庫連線成功\n";
};

if ($@) {
    print "❌ 資料庫連線失敗: $@\n";
    print "\n🔧 請確認:\n";
    print "1. PostgreSQL 服務已啟動\n";
    print "2. 資料庫已建立: createdb -U postgres $db_config->{database}\n";
    print "3. 用戶已建立並有權限:\n";
    print "   psql -U postgres -c \"CREATE USER $db_config->{username} WITH PASSWORD '$db_config->{password}';\"\n";
    print
      "   psql -U postgres -c \"GRANT ALL PRIVILEGES ON DATABASE $db_config->{database} TO $db_config->{username};\"\n";
    exit 1;
}

# 檢查資料表是否已存在
print "\n📊 檢查資料表...\n";

my $table_exists =
  $dbh->selectrow_array("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'processing_jobs')");

if ($table_exists) {
    print "⚠️  資料表 'processing_jobs' 已存在\n";
    print "是否要重新建立資料表？這將刪除所有現有資料！ (y/N): ";

    my $response = <STDIN>;
    chomp $response;

    unless ( $response =~ /^[yY]/ ) {
        print "✅ 保持現有資料表，初始化完成\n";
        $dbh->disconnect;
        exit 0;
    }

    print "🗑️  刪除現有資料表...\n";
    $dbh->do("DROP TABLE IF EXISTS processing_jobs CASCADE");
}

# 建立資料表
print "🔨 建立資料表...\n";

my $create_table_sql = q{
    CREATE TABLE processing_jobs (
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
    )
};

eval {
    $dbh->do($create_table_sql);
    print "✅ 資料表 'processing_jobs' 建立成功\n";
};

if ($@) {
    print "❌ 建立資料表失敗: $@\n";
    $dbh->disconnect;
    exit 1;
}

# 建立索引
print "🔍 建立索引...\n";

my @indexes = (
    "CREATE INDEX idx_process_id ON processing_jobs(process_id)",
    "CREATE INDEX idx_status ON processing_jobs(status)",
    "CREATE INDEX idx_created_at ON processing_jobs(created_at)"
);

for my $index_sql (@indexes) {
    eval { $dbh->do($index_sql); };
    if ($@) {
        print "⚠️  索引建立失敗: $@\n";
    }
}

print "✅ 索引建立完成\n";

# 測試插入和查詢
print "\n🧪 執行基本測試...\n";

eval {
    # 插入測試資料
    $dbh->do(
        q{
        INSERT INTO processing_jobs (process_id, status, progress, created_at)
        VALUES ('test_123', 'completed', '100%', NOW())
    }
    );

    # 查詢測試資料
    my $result = $dbh->selectrow_hashref("SELECT * FROM processing_jobs WHERE process_id = 'test_123'");

    if ( $result && $result->{process_id} eq 'test_123' ) {
        print "✅ 資料插入和查詢測試成功\n";

        # 清理測試資料
        $dbh->do("DELETE FROM processing_jobs WHERE process_id = 'test_123'");
    }
    else {
        print "❌ 資料查詢測試失敗\n";
    }
};

if ($@) {
    print "❌ 測試執行失敗: $@\n";
}

# 顯示資料表資訊
print "\n📋 資料表資訊:\n";

my $table_info = $dbh->selectall_arrayref(
    q{
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_name = 'processing_jobs'
    ORDER BY ordinal_position
}, { Slice => {} }
);

for my $col (@$table_info) {
    printf "   %-20s %-15s %s %s\n",
      $col->{column_name},
      $col->{data_type},
      $col->{is_nullable} eq 'YES' ? 'NULL'                           : 'NOT NULL',
      $col->{column_default}       ? "DEFAULT $col->{column_default}" : '';
}

$dbh->disconnect;

print "\n🎉 PostgreSQL 資料庫初始化完成！\n";
print "\n🚀 現在可以啟動 API 伺服器:\n";
print "   perl start_server_example.pl\n";
print "\n📖 更多資訊請參考: postgresql_setup.md\n";
