#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

# 載入你的 Dancer2 應用程式
use YourApp::API::Upload;
use Dancer2;

# 設定
set port         => 5120;
set host         => '127.0.0.1';
set startup_info => 1;
set show_errors  => 1;
set log          => 'debug';

# 如果你有其他設定檔
# config_file("$FindBin::Bin/../config.yml");

# 啟動應用程式
start;
