# scheduled_task

#### 目次

1. [説明](#description)
2. [セットアップ - scheduled_task導入の基本](#setup)
    * [scheduled_taskモジュールが影響を与えるもの:](#what-scheduled_task-affects)
    * [セットアップ要件](#setup-requirements)
    * [scheduled_taskモジュールの利用方法](#beginning-with-scheduled_task)
3. [使用 - 設定オプションと追加機能](#usage)
4. [参考 - モジュールの機能と動作について](#reference)
5. [制約 - OS互換性など](#limitations)
6. [開発 - モジュール貢献についてのガイド](#development)

## 説明

このモジュールは、タスク管理に最新のVersion 2 Windows APIを使用できる新しい[scheduled_task](https://puppet.com/docs/puppet/latest/types/scheduled_task.html)プロバイダを追加するものです。
旧バージョンのAPIは改良点や新機能を受けとれないため、Windows上のスケジュールされたタスクに改良点を利用したい場合は、V2 APIを使用する必要があります。

## セットアップ

### scheduled_taskモジュールの利用方法

scheduled_taskモジュールは、Puppet [scheduled_task](https://puppet.com/docs/puppet/latest/types/scheduled_task.html)リソースを適応させ、最新APIを用いて実行するようにします。
使用を開始するには、モジュールをインストールします。インストールすると、既存の`scheduled_task`リソースが**デフォルトで**V2 APIを使用するようになります。
旧バージョンのAPIのプロバイダの使用を継続したい場合は、マニフェストでそれを宣言する_必要_があります。
例えば、以下のようになります。

~~~ puppet
scheduled_task { 'Run Notepad':
  command  => "notepad.exe",
  ...
  provider => 'win32_taskscheduler',
}
~~~

## 使用

スケジュールされたタスクは通常、スクリプトを1回または定期的に開始するために用いられます。
この最初の例では、クリーンアップスクリプトを1回だけ実行するようにスケジュールします。

~~~ puppet
scheduled_task { 'Disk Cleanup': # Unique name for the scheduled task
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',           # This is the default, but including it is good practice. Flip to 'false' to disable the task.
  trigger   => [{
    schedule   => 'once',        # Defines the trigger type; required.
    start_time => '23:20',       # Defines the time the task should run; required.
    start_date => '2018-01-01'   # Defaults to the current date; not required.
  }],
}
~~~

クリーンアップスクリプトを毎晩実行する必要がある場合は、デイリートリガーを使用できます。
トリガースケジュールを`once`から`daily`に変更するだけで設定できます。
`start_date`をトリガーから削除したことに注目してください。これは、このタスクには不要で、重要でもありません。

~~~ puppet
scheduled_task { 'Disk Cleanup Nightly':
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    schedule   => 'daily',
    start_time => '23:20'
  }],
}
~~~

設定したタイムブロックの期間中に、スケジュールされたタスクが繰り返されるように設定することもできます。
またクリーンアップスクリプトの例を使うと、このスケジュールされたタスクは毎日同じ時間に開始され、朝7時から夜7時までの間、1時間に1回、SYSTEMアカウントとして実行されます。

~~~ puppet
scheduled_task { 'Disk Cleanup Daily Repeating':
  ensure    => 'present',
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    'schedule'         => 'daily',
    'start_time'       => '07:00',
    'minutes_duration' => '720',   # Specifies the length of time, in minutes, the task is active
    'minutes_interval' => '60'     # Causes the task to run every hour
  }],
  user      => 'system',           # Specifies the account to run the task as
}
~~~

このタスクの欠点は、クリーンアップスクリプトが毎日実行されるため、活動が行われない週末にも実行されることです。
かわりにウィークリートリガーを使えば、この点を修正できます。

~~~puppet
scheduled_task { 'Disk Cleanup Weekly Repeating':
  ensure    => 'present',
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    'schedule'         => 'weekly',
    'start_time'       => '07:00',
    'day_of_week'      => ['mon', 'tues', 'wed', 'thu', 'fri'], # Note the absence of Sunday and Monday
    'minutes_interval' => '60',
    'minutes_duration' => '720'
  }],
  user      => 'system',
}
~~~

同様に、クリーンアップスクリプトをそれほど頻繁に実行する必要がない場合や、クリーンアップスクリプトが特にリソースを消費する場合は、毎月1回実行されるようにスケジュールすることができます。
以下の例では、毎月最初の日の07:00にスケジュールされたタスクを実行するように設定しています。

~~~puppet
scheduled_task { 'Disk Cleanup Monthly First Day':
  ensure    => 'present',
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    'schedule'   => 'monthly',
    'start_time' => '07:00',
    'on'         => [1]        # Run every month on the first day of the month.
  }],
  user      => 'system',
}
~~~

上述のマンスリートリガーでは、毎月最初の日が週末だという保証はありません。
そのため、スクリプトが就業時間中に実行され、生産性に影響を与える可能性がかなりあります。
毎月最初の日のかわりに、毎月最初の土曜日にタスクを実行するようにトリガーを指定することもできます。

~~~puppet
scheduled_task { 'Disk Cleanup Monthly First Saturday':
  ensure    => 'present',
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    'schedule'        => 'monthly',
    'start_time'      => '07:00',
    'day_of_week'     => 'sat',     # Specify the day of the week to trigger on
    'which_occurence' => 'first'    # Specify which occurance to trigger on, up to fifth
  }],
  user      => 'system',
}
~~~

コンピュータを起動するたびに毎回タスクを実施したいケースもあるかもしれません。

~~~puppet
scheduled_task { 'Disk Cleanup On Restart':
  ensure        => 'present',
  compatibility => 2,
  command       => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments     => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled       => 'true',
  trigger       => [{
    'schedule'  => 'boot',
    'minutes_interval' => '60',
    'minutes_duration' => '720'
  }],
  user          => 'system',
}
~~~
* 注意: `minutes_duration`や`minutes_interval`などの期間属性は、`boot`トリガーでは`compatibility => 2`以上で指定する必要があります。Windowsでは、このオプションは、互換性が指定されていない場合にデフォルトになる「Windows XPまたはWindows Server 2003コンピュータ」互換性レベルではサポートされていません。

ログオン時にタスクを実行したい場合は、`logon`トリガーを使用します。

~~~puppet
scheduled_task { 'example_notepad':
  compatibility => 2,
  command       => 'C:\\Windows\\System32\\notepad.exe',
  trigger       => [{
    schedule => 'logon',
    user_id  => 'MyDomain\\SomeUser'
  }],
}
~~~

## リファレンス

### プロバイダ

* win32_taskscheduler: このレガシープロバイダは、レガシーAPIを模倣するWindowsでスケジュールされたタスクを管理します。
* taskscheduler_api2: Puppet scheduled_taskリソースを、最新のVersion 2 APIを使用するように適応させます。

### タイプ

#### scheduled_task

Windows Scheduled Taskをインストールして管理します。
`name`、`command`、`trigger`を除くすべての属性はオプションです。 スケジュール設定の詳細は、[`trigger`](#trigger)属性の説明を参照してください。

##### `name`

スケジュールされたタスクに割り当てられた名前。
システム上のタスクを一意的に特定します。

##### `ensure`

リソースの基本的なプロパティ。

有効な値は`present`、`absent`です。

##### `arguments`

コマンドに渡されるべき引数またはフラグ。
複数の引数は、スペースで区切られた文字列として指定する必要があります。

##### `command`

実行するアプリケーションのフルパスを引数なしで指定します。

##### `enabled`

このタスクのトリガーを有効にするかどうかを指定します。
この属性は、タスクのすべてのトリガーに影響を与えます。複数のトリガーを個別に有効または無効にすることはできません。

有効な値：`true`、`false`。

##### `password`

'user'属性で指定されたユーザのパスワード。
'SYSTEM'以外のユーザを指定する場合にのみ使用されます。
このパラメータは、スケジュールされたタスクが同期しているかどうかを決定するためには使用されません。これは、タスクのアカウント情報を設定するために用いられるパスワードを探す方法がないためです。

##### `compatibility`

このプロバイダ機能は、`taskscheduler_api2`プロバイダでのみ使用できます。

タスクに関連する互換性レベル。
下位互換性のデフォルト値は1です。
以下のように設定できます。

- `1`: Windows XPまたはWindows Server 2003コンピュータ上のタスクとの互換性。
- `2`: Windows 2008コンピュータ上のタスクとの互換性。
- `3`: Windows 7および2008R2で導入されたタスクの新機能との互換性。
- `4`: Windows 8、Server 2012R2、Server 2016で導入されたタスクの新機能との互換性。
- `6`: Windows 10で導入されたタスクの新機能との互換性。
  - **注意:** この互換性設定は文書化されていないため、使用しないことを推奨します。

詳細については、[各種の互換性レベルとその違いに関するMicrosoftの文書](https://msdn.microsoft.com/en-us/library/windows/desktop/aa384138\(v=vs.85\).aspx)を参照してください。

##### `provider`

このscheduled_taskリソースに関して使用する特定のバックエンド。
この指定が必要になることはめったにありません。通常は、Puppetがお使いのプラットフォームに適したプロバイダを見つけます。

使用可能なプロバイダは以下のとおりです。

###### win32_taskscheduler

このレガシープロバイダは、v2 apiを使ってWindows上でスケジュールされたタスクを管理しますが、互換性レベルが1に設定されているスケジュールされたタスクのみを管理します(Windows XPまたはWindows Server 2003)。
下位互換性アップデートで、Puppetコアの同名のプロバイダと置き換えられます。

###### taskscheduler_api2

このプロバイダは、v2 apiを使ってWindows上でスケジュールされたタスクを管理します。あらゆる互換性レベルのスケジュールされたタスクを管理できます。

* `operatingsystem` == `windows`のデフォルト。

##### `trigger`

タスクを実行すべきときを決定する1つまたは複数のトリガー。
1つのトリガーはハッシュとして表されます。複数のトリガーはハッシュの配列で指定できます。

トリガーには以下のキーを含めることができます。

すべてのトリガー:

* `schedule` (必須) — トリガーの種類。
  有効な値は`daily`、`weekly`、`monthly`、`once`、`boot`、`logon`です。
  それぞれの種類のトリガーは、異なるキーセットにより設定します。以下のセクションを参照してください(onceトリガーには開始時間/日付が必要です)。
* `start_time` (`boot`以外では必須) — トリガーが最初にアクティブになるべき日の時間。
  複数の時間フォーマットを使用できますが、24時間のHH:MMフォーマットを推奨します。
* `start_date` — トリガーが最初にアクティブになるべき日付。
  デフォルト値は現在の日付です。
  YYYY-MM-DDのフォーマットにする必要がありますが、別の日付フォーマットでも機能する場合があります(内部ではDate.parseが使用されます)。
* `minutes_interval` — 分単位の反復間隔。
* `minutes_duration` — 分単位の期間。minutes_intervalよりも長くする必要があります。
* デイリートリガー:
  * `every` — タスクを実行すべき頻度。日数として指定します。
    デフォルト値は1です。
    "2"は1日おき、"3"は3日に1回、などの意味になります。
* ウィークリートリガー:
  * `every` — タスクを実行すべき頻度。週数として指定します。
    デフォルト値は1です。
    "2"は1週間おき、"3"は3週間に1回、などの意味になります。
  * `day_of_week` — タスクを実行すべき週の曜日。配列として指定します。
    デフォルト値はすべての曜日です。
    各曜日は`mon`、`tues`、`wed`、`thurs`、`fri`、`sat`、`sun`、`all`のいずれかにする必要があります。
* マンスリー(日付で指定)トリガー:
  * `months` — タスクを実行すべき月。配列として指定します。
    デフォルト値はすべての月です。
    各月は1から12までの整数にする必要があります。
  * `on` (必須) — タスクを実行すべき月の日。配列として指定します。
    各日は1から31までの整数にする必要があります。
* マンスリー(曜日で指定)トリガー:
  * `months` — タスクを実行すべき月。配列として指定します。各月は1から12までの整数にする必要があります。
  * `day_of_week` (必須) — タスクを実行すべき週の曜日。1つの要素のみをもつ配列として指定します。
    各曜日は`mon`、`tues`、`wed`、`thurs`、`fri`、`sat`、`sun`、`all`のいずれかにする必要があります。
  * `which_occurrence` (必須) — タスクを実行すべき選択した曜日の発生時期。`first`、`second`、`third`、`fourth`、`last`のいずれかにする必要があります。
* `logon`トリガー:
  * `user_id` --- `user_id`は、ログイン時にこのタスクを開始するユーザを指定します。
    指定されていない場合、`undef`と指定されている場合、または空文字列の場合は、
    タスクは**すべての**ユーザのログオン時に開始されます。
    この特性は、以下のいずれかの形式で指定できます。
    * ローカルユーザ: `"Administrator"`
    * ドメインユーザ: `"MyDomain\\MyUser"`
    * SID: `"S-15-..."`
    * 任意のユーザ: `''`または`undef`

##### `user`

スケジュールされたタスクを実行するユーザ。
デフォルト値は'SYSTEM'です。

`scheduled_task`リソースを管理するためには、権限のあるユーザとしてPuppetを実行する必要がある点にも注意してください。
権限のないユーザとして実行すると、'access denied'エラーが生じます。

##### `working_dir`

コマンドを開始するディレクトリのフルパス。

## 制約

* Windows Server 2008以上およびWindows 7以上でのみサポートされています。

## 開発

Puppet ForgeのPuppetモジュールはオープンプロジェクトで、良い状態に保つためには、コミュニティの貢献が必要不可欠です。Puppetが役に立つはずでありながら、私たちがアクセスできないプラットフォームやハードウェア、ソフトウェア、デプロイ構成は無数にあります。そのため、できる限り簡単に変更に貢献し、みなさまの環境で私たちのモジュールが機能できるようにすることを目標にしています。最高の状態に維持できるようにするために、コントリビュータが従う必要のあるいくつかのガイドラインが存在します。詳細については、[モジュール貢献ガイド](https://docs.puppet.com/forge/contributing.html)を参照してください。
