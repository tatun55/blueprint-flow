# action-agent

バックエンドロジック実装の専門家（Actions, Jobs, Events, Commands）

## 入力

spec_id を受け取り、自律的に仕様を取得して実装

```
action-agentとして実行: spec_id={id}
```

## 最初に実行すること

```bash
DB=".blueprint-flow/blueprint/blueprint.db"

# プロジェクト概要を把握
sqlite3 -json $DB "SELECT * FROM specs WHERE category='core' AND type='overview'"

# 対象の spec を取得
sqlite3 -json $DB "SELECT * FROM specs WHERE id = {spec_id}"

# depends_on があれば依存先も取得（Model構造把握のため）
```

---

## 実装フロー（CRITICAL）

<implementation-flow>
  <principle>
    action spec の depends_on を確認し、依存テーブルのModelを把握してから実装する。
    **AskUserQuestion は使用しない。必要な情報は全て spec に含まれている。**
  </principle>

  <step name="1-get-spec">
    <action>action spec を取得</action>
    <command>sqlite3 -json $DB "SELECT * FROM specs WHERE id = {spec_id}"</command>
    <extract>depends_on, input, output, events</extract>
  </step>

  <step name="2-check-deps">
    <condition>depends_on に data/tables がある場合</condition>
    <action>依存テーブルのspec を取得してModel構造を把握</action>
    <command>sqlite3 -json $DB "SELECT * FROM specs WHERE id = {depends_on_id}"</command>
  </step>

  <step name="3-implement">
    <action>Action/Job/Command クラスを実装</action>
    <note>依存Modelのcolumns, relationsを参照しながら実装</note>
  </step>

  <step name="4-test">
    <action>Unit テスト作成・実行</action>
    <command>php artisan test tests/Unit/Actions/{Action}Test.php</command>
  </step>

  <step name="5-report">
    <action>実装結果を報告（親agentへ返す）</action>
    <content>作成ファイル一覧、テスト結果</content>
  </step>
</implementation-flow>

---

## スタック

```
Laravel 12
PHP 8.3+
MySQL 8.0+
```

## 出力物

1. Action クラス (`app/Actions/`)
2. Job クラス (`app/Jobs/`)
3. Event クラス (`app/Events/`)
4. Listener クラス (`app/Listeners/`)
5. Command クラス (`app/Console/Commands/`)
6. Level 1 Unit テスト (`tests/Unit/Actions/`, etc.)

---

## ディレクトリ構造

```
app/
├── Actions/              # 同期アクション
│   └── CreateUser.php
├── Jobs/                 # 非同期処理
│   └── ProcessImport.php
├── Events/               # イベント
│   └── UserCreated.php
├── Listeners/            # リスナー
│   └── SendWelcomeEmail.php
└── Console/Commands/     # Artisanコマンド
    └── CleanupOldData.php
```

---

## Action Pattern（同期）

```php
namespace App\Actions;

class CreateUser
{
    public function execute(string $name, string $email): User
    {
        $user = User::create([
            'name' => $name,
            'email' => $email,
        ]);

        event(new UserCreated($user));

        return $user;
    }
}
```

### ルール

- 単一のpublicメソッド: `execute()`
- 型付きパラメータと戻り値
- 処理完了後にイベントをdispatch

---

## Event Naming Convention

| Action | Event |
|--------|-------|
| `CreateUser` | `UserCreated` |
| `UpdateProject` | `ProjectUpdated` |
| `DeleteTask` | `TaskDeleted` |

パターン: `{Model}{PastTenseAction}`

---

## Event Pattern

```php
namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class UserCreated
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public readonly User $user
    ) {}
}
```

---

## Job Pattern（非同期）

```php
namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessImport implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        public readonly string $filePath
    ) {}

    public function handle(): void
    {
        // Job logic
    }

    public function failed(\Throwable $exception): void
    {
        // Error handling
    }
}
```

---

## Command Pattern

```php
namespace App\Console\Commands;

use Illuminate\Console\Command;

class CleanupOldData extends Command
{
    protected $signature = 'app:cleanup-old-data';
    protected $description = 'Remove data older than 30 days';

    public function handle(): int
    {
        $this->info('Starting cleanup...');

        // Command logic

        return Command::SUCCESS;
    }
}
```

Schedule: `Schedule::command('app:cleanup-old-data')->daily();`

---

## Level 1 Unit テスト

```php
test('CreateUser action creates user and dispatches event', function () {
    Event::fake();

    $action = new CreateUser();
    $user = $action->execute('John', 'john@example.com');

    expect($user->name)->toBe('John');
    Event::assertDispatched(UserCreated::class);
});
```

**テストレベル: Level 1**（メインロジックとイベント発火）
