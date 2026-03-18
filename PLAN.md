# PLAN: Spinel AOT Compiler

Ruby source → Prism AST → whole-program type inference → standalone C executable.
No runtime dependencies (no mruby, no GC library — GC is generated inline).
Regexp対応プログラムのみ libonig をリンク。

詳細設計は `ruby_aot_compiler_design.md` を参照。

---

## 現状 (Status)

### コンパイラアーキテクチャ (~7700行のC)

- Prism (libprism) によるRubyパース
- 多パスコード生成:
  1. クラス/モジュール/関数解析 (継承チェーン、mixin解決、Struct.new展開含む)
  2. 全変数・パラメータ・戻り値の型推論 (関数間解析)
  3. C構造体・メソッド関数の生成 (GCスキャン関数含む)
  4. ラムダ/クロージャのキャプチャ解析・コード生成
  5. yield/ブロックのコールバック関数生成 (block_given?対応)
  6. 正規表現パターンのプリコンパイル (oniguruma)
  7. main()のトップレベルコード生成
- マーク&スイープGC (シャドウスタック、ファイナライザ)
- setjmp/longjmpベース例外処理 (クラス例外階層対応)
- アリーナアロケータ (ラムダ/クロージャ用)

### サポート済み言語機能

| カテゴリ | 機能 |
|---------|------|
| **OOP** | クラス定義、インスタンス変数、メソッド定義 |
| | 継承 (`class Dog < Animal`)、`super` |
| | `include` (mixin) — モジュールのインスタンスメソッド取り込み |
| | `attr_accessor` / `attr_reader` / `attr_writer` |
| | クラスメソッド (`def self.foo`) |
| | `Struct.new(:x, :y)` — 合成クラス生成 |
| | `alias` — メソッド別名 |
| | `freeze`/`frozen?` — AOTでは全値がfrozen扱い |
| | getter/setter自動インライン化 |
| | コンストラクタ (`.new`)、型付きオブジェクトへのメソッド呼び出し |
| | モジュール (状態変数 + メソッド) |
| **イントロスペクション** | `is_a?` — 継承チェーンをコンパイル時に静的解決 |
| | `respond_to?` — メソッドテーブルをコンパイル時に静的解決 |
| | `nil?` — nil以外は常にFALSE |
| | `defined?` — 変数定義チェック (コンパイル時) |
| **ブロック/クロージャ** | `yield`、ブロック付きメソッド呼び出し (キャプチャ変数) |
| | `block_given?` — ブロックの有無チェック |
| | `Array#each/map/select/reject/reduce/inject` (インライン化) |
| | `Hash#each` (キー/値ペア) |
| | `Integer#times/upto/downto` with block → C forループ |
| | `-> x { body }` ラムダ → Cクロージャ (キャプチャ解析) |
| **制御** | while, until, if/elsif/else, unless |
| | case/when/else (値、複数値、Range条件) |
| | for..in + Range, loop do |
| | break, next, return |
| | ternary, and/or/not |
| | `__LINE__`, `__FILE__`, `__method__`, `defined?` |
| | `catch`/`throw` (タグ付き非局所脱出) |
| **例外処理** | begin/rescue/ensure/retry |
| | `raise "message"`, `raise ClassName, "message"` |
| | `rescue ClassName => e` (クラス階層チェック付き) |
| | 複数rescue節の連鎖 |
| | volatile変数でlongjmpの値保存 |
| **引数** | 位置引数、デフォルト値 (`def foo(x = 10)`) |
| | キーワード引数 (`def foo(name:, greeting: "Hello")`) |
| | 可変長引数/スプラット (`def sum(*nums)`) |
| **型** | Integer, Float, Boolean, String, Symbol, nil → アンボックスC型 |
| | 値型 (Vec: 3 floats → 値渡し) vs ポインタ型 |
| **コレクション** | sp_IntArray (push/pop/shift/dup/reverse!/each/map/select/reject/reduce) |
| | Array#first/last/include?/sort/sort!/min/max/sum/length |
| | sp_StrIntHash (文字列キー→整数値、each/has_key?/delete) |
| | sp_StrArray (文字列配列、split結果用) |
| | O(1) shift (デキュー方式のstartオフセット) |
| **正規表現** | `/pattern/` リテラル → onigurumaプリコンパイル |
| | `=~`、`$1`-`$9` キャプチャグループ |
| | `match?`, `gsub`, `sub`, `scan` (ブロック付き), `split` |
| **演算** | 算術 (+, -, *, /, %, **), 比較, ビット演算 |
| | 単項マイナス, 複合代入 (+=, <<=) |
| | Math.sqrt/cos/sin → C math関数 |
| | Integer#abs/even?/odd?/zero?/positive?/negative? |
| | Float#abs/ceil/floor/round |
| **文字列** | リテラル、補間 → printf |
| | 15+メソッド: length, upcase, downcase, strip, reverse |
| |   gsub, sub, split, capitalize, chomp |
| |   include?, start_with?, end_with?, count |
| |   +, <<, * (連結、追記、繰り返し) |
| |   ==, !=, <, > (strcmp比較) |
| | Integer#to_s, Integer#chr |
| **I/O** | puts, print, printf, putc, p → stdio |
| | puts: Integer, Float, Boolean, String対応 (末尾改行のRuby互換) |
| | File.read, File.write, File.exist?, File.delete |
| **GC** | マーク&スイープ (非値型オブジェクト・配列・ハッシュ用) |
| | シャドウスタックルート管理, ファイナライザ |
| | GC不要なプログラムではGCコード省略 |

### テストプログラム (30例)

| プログラム | テスト対象 |
|-----------|-----------|
| bm_so_mandelbrot | while、ビット演算、PBM出力 |
| bm_ao_render | 6クラス、モジュール、GC |
| bm_so_lists | 配列操作 (push/pop/shift)、GC |
| bm_fib | 再帰、関数型推論 |
| bm_app_lc_fizzbuzz | 1201クロージャ、アリーナ |
| bm_mandel_term | 関数間呼び出し、putc |
| bm_yield | yield/ブロック、each/map/select |
| bm_case | case/when、unless、next、デフォルト引数 |
| bm_inherit | 継承、super |
| bm_rescue | rescue/raise/ensure/retry |
| bm_hash | Hash操作 |
| bm_strings | Symbol、基本文字列メソッド |
| bm_strings2 | 高度な文字列メソッド、split、比較 |
| bm_numeric | 数値メソッド (abs, ceil, even?, **) |
| bm_attr | attr_accessor、for..in、loop、クラスメソッド |
| bm_kwargs | キーワード引数、スプラット |
| bm_mixin | include (mixin) |
| bm_misc | upto/downto、String <<、配列引数 |
| bm_regexp | 正規表現 (=~, $1, match?, gsub, sub, scan, split) |
| bm_introspect | is_a?, respond_to?, nil?, positive?, negative? |
| bm_struct | Struct.new |
| bm_array2 | Array#reject/first/last/include? |
| bm_sort_reduce | Array#sort/min/max/sum/reduce/inject |
| bm_control | __LINE__, __FILE__, defined? |
| bm_exceptions | raise ClassName, rescue ClassName, 例外階層 |
| bm_block2 | block_given?, ブロック付きyield呼び出し |
| bm_fileio | File.read/write/exist?/delete |
| bm_catch | catch/throw (タグ付き非局所脱出) |
| bm_features | __method__, freeze/frozen? |
| bm_comparable | alias メソッド別名 |

### ベンチマーク結果

| ベンチマーク | CRuby | mruby | Spinel AOT | 高速化 | メモリ |
|-------------|-------|-------|------------|--------|--------|
| mandelbrot (600×600) | 1.14s | 3.18s | 0.02s | 57× | <1MB |
| ao_render (64×64 AO) | 3.55s | 13.69s | 0.07s | 51× | 2MB |
| so_lists (300×10K) | 0.44s | 2.01s | 0.02s | 22× | 2MB |
| fib(34) | 0.55s | 2.78s | 0.01s | 55× | <1MB |
| lc_fizzbuzz (Church) | 28.96s | — | 1.55s | 19× | arena |
| mandel_term | 0.05s | 0.05s | ~0s | 50×+ | <1MB |

生成バイナリは完全スタンドアロン (libc + libm のみ、mruby不要)。
Regexp使用時のみ libonig をリンク。

---

## 全Rubyコンパイルへの残課題 (10カテゴリ)

| # | カテゴリ | 状態 | 次のアクション |
|---|---------|------|-------------|
| 1 | **動的型付け / ポリモーフィズム** | 設計完了 | sp_RbValue Phase 1 実装 |
| 2 | **require / load / gem** | 未着手 | ファイル解決 + AST統合 |
| 3 | **Block/Proc完全性** | 一部完了 | `&block`, `Proc.new`, proc vs lambda意味論 |
| 4 | **組込クラス** | 一部完了 | Time, Range-as-object, Enumerator |
| 5 | **完全なString** | 未着手 | sp_String構造体 (ミュータブル + encoding) |
| 6 | **オブジェクトシステム完全性** | 未着手 | method_missing等はインタプリタフォールバック |
| 7 | **制御フロー完全性** | ほぼ完了 ✅ | 残: BEGIN/END のみ |
| 8 | **パターンマッチ** | 未着手 | sp_RbValue (ポリモーフィズム) が前提 |
| 9 | **例外階層** | 完了 ✅ | raise ClassName, rescue ClassName, 継承チェック |
| 10 | **GC完全性** | 一部完了 | 文字列GC (sp_String), 世代別GC |

### 完了した項目
- ✅ `__LINE__`, `__FILE__`, `defined?`, `__method__`
- ✅ `catch`/`throw` (タグ付き非局所脱出、ネスト対応)
- ✅ `freeze`/`frozen?` (AOTではno-op / 常にTRUE)
- ✅ `alias` (メソッド別名)
- ✅ `block_given?`, ブロック変数のwrite-capture修正
- ✅ `raise ClassName, "msg"`, `rescue ClassName => e`, 例外クラス継承チェック
- ✅ `File.read/write/exist?/delete`
- ✅ `Array#sort/sort!/min/max/sum/reduce/inject`
- ✅ `puts` の末尾改行Ruby互換

---

## ポリモーフィズム設計

### 方針: ハイブリッド型システム (Crystal方式)

現在の**単相最適化を維持**しつつ、必要な箇所にのみ**ボックス化**を導入する。

```
型推論の結果:
  変数が常に1つの型 → 現在通り: mrb_int, mrb_float, sp_Vec, etc. (アンボックス)
  変数が複数の型    → sp_RbValue (ボックス化タグ付きユニオン)
```

### sp_RbValue: 汎用ボックス型

```c
// Phase 1: 16バイトタグ付きユニオン (シンプル、デバッグ容易)
enum sp_tag {
    SP_T_INT, SP_T_FLOAT, SP_T_BOOL, SP_T_NIL,
    SP_T_STRING, SP_T_SYMBOL, SP_T_ARRAY, SP_T_HASH,
    SP_T_OBJECT, SP_T_PROC, SP_T_REGEXP
};

typedef struct {
    enum sp_tag tag;
    union {
        int64_t i;       // SP_T_INT
        double f;        // SP_T_FLOAT
        const char *s;   // SP_T_STRING, SP_T_SYMBOL
        void *p;         // SP_T_OBJECT, SP_T_ARRAY, SP_T_HASH, SP_T_PROC
    };
} sp_RbValue;  // 16 bytes

// Phase 2 (将来): NaN-boxing (8バイト、高速)
```

### メソッドディスパッチ

| 多相度 | 方式 | 速度 |
|--------|------|------|
| 単相 (型確定) | 直接C関数呼び出し | 最速 (現在) |
| 少多相 (2-3型) | switch on tag | 高速 |
| 多多相 (4型+) | vtable/hash | 中速 |

### 実装ロードマップ

| Phase | 内容 | 前提 |
|-------|------|------|
| 1 | sp_RbValue + boxing/unboxing + 基本演算 | — |
| 2 | Union型追跡 + switch dispatch | Phase 1 |
| 3 | 異種Array/Hash | Phase 1 |
| 4 | ダックタイピング + vtable | Phase 2 |
| 5 | NaN-boxing + inline cache + LumiTrace | Phase 1-4 |

### 設計原則

1. **段階的導入**: 既存の単相コンパイルを壊さない
2. **性能優先**: 単相パスは現在の速度を維持
3. **互換性**: 最終的に全valid Rubyをコンパイル可能に
4. **NaN-boxing準備**: Phase 1をPhase 5で置き換え可能な設計

### sp_RbValue待ちの機能
- `Comparable` モジュール (演算子メソッド `<=>` のC名サニタイズが必要)
- `Range` as object (sp_Range構造体 + メソッドセット)
- パターンマッチ `case/in` (型チェック分岐)
- 異種配列/Hash
- ダックタイピング

---

## プロジェクト構成

```
spinel/
├── src/
│   ├── main.c          # CLI、ファイル読み込み、Prismパース
│   ├── codegen.h       # 型システム、クラス/メソッド/モジュール情報構造体
│   └── codegen.c       # 多パスコード生成器 (~7700行)
├── examples/           # 30テストプログラム
├── prototype/
│   └── tools/          # Step 0プロトタイプ (RBS抽出、LumiTrace等)
├── Makefile
├── PLAN.md             # 本文書
└── ruby_aot_compiler_design.md  # 詳細設計文書
```

## ビルドフロー

```bash
make deps && make         # コンパイラビルド
./spinel --source=app.rb --output=app.c
cc -O2 app.c -lm -o app  # Regexp使用時は -lonig 追加
```

## 参考情報

- 詳細設計: `ruby_aot_compiler_design.md`
- プロトタイプツール: `prototype/`
- 参考実装: Crystal, TruffleRuby, Sorbet, mruby
