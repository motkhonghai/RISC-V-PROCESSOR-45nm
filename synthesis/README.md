# Hướng dẫn chạy MMMC synthesis cho PicoRV32

## 1. Mục đích

Script chính:

`/home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/run_mmmc.tcl`

Script thực hiện synthesis RTL `picorv32` bằng Cadence Genus Stylus với hai
timing corner:

- Slow corner 0.9 V, 125°C dùng cho setup analysis.
- Fast corner 1.1 V, 0°C dùng cho hold analysis.

Flow gồm các bước:

1. Khai báo đường dẫn và cấu hình Genus.
2. Nạp MMMC, Liberty, LEF và RTL.
3. Elaborate và kiểm tra design/timing intent.
4. Tạo các timing path group.
5. Chạy `syn_generic`.
6. Chạy `syn_map`.
7. Chạy `syn_opt`.
8. Xuất report, netlist, SDC và database cho Innovus.

## 2. Cấu trúc thư mục

Flow sử dụng cấu trúc sau:

```text
RISC-V-PROCESSOR/
├── mmmc.view
├── rtl/
│   └── picorv32.v
├── lib/
│   ├── slow_vdd1v0_basicCells.lib
│   └── fast_vdd1v0_basicCells.lib
├── lef/
│   ├── gsclib045_tech.lef
│   └── gsclib045_macro.lef
├── QRC_Tech/
│   └── gpdk045.tch
├── constraints/
│   └── picorv32.sdc
└── synthesis/
    ├── run_mmmc.tcl
    ├── outputs/mmmc/
    └── reports/mmmc/
```

Hai thư mục output và report được script tự tạo nếu chưa tồn tại.

## 3. Quy ước đường dẫn

Script chỉ cố định thư mục cha một lần:

```tcl
set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
```

Các đường dẫn còn lại được tạo từ thư mục cha:

```tcl
set SYNTHESIS_PATH ${PROJECT_PATH}/synthesis
set RTL_PATH       ${PROJECT_PATH}/rtl
set LIB_PATH       ${PROJECT_PATH}/lib
set LEF_PATH       ${PROJECT_PATH}/lef
set OUTPUTS_PATH   ${SYNTHESIS_PATH}/outputs/mmmc
set REPORTS_PATH   ${SYNTHESIS_PATH}/reports/mmmc
set MMMC_FILE      ${PROJECT_PATH}/mmmc.view
```

Flow bắt ambiguity working directory bằng cách chuyển về thư mục cha:

```tcl
cd $PROJECT_PATH
```

Không sử dụng `file join`, `info script` hoặc đường dẫn tương đối `../`.

Nếu project được chuyển sang vị trí khác, chỉ cần sửa `PROJECT_PATH` trong:

1. `synthesis/run_mmmc.tcl`.
2. `mmmc.view`.

## 4. Điều kiện trước khi chạy

Cần kiểm tra:

- Cadence Genus đã được cài đặt và có license hợp lệ.
- Lệnh `genus` có trong biến môi trường `PATH`.
- Tất cả file RTL, Liberty, LEF, SDC và QRC tồn tại.
- Thư mục project có quyền đọc và ghi.
- Phiên bản Genus hỗ trợ Stylus/Common UI.

Kiểm tra executable:

```bash
which genus
genus -version
```

Không chạy script bằng `tclsh`, vì các lệnh như `set_db`, `read_mmmc`,
`syn_generic` và `write_snapshot` là lệnh riêng của Genus.

## 5. Cách chạy

Chạy trực tiếp ở chế độ Stylus:

```bash
genus -stylus -files /home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/run_mmmc.tcl
```

Để lưu log từ shell:

```bash
genus -stylus \
  -files /home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/run_mmmc.tcl \
  |& tee /home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/genus_mmmc.log
```

Nếu muốn Genus tự thoát sau khi chạy batch, bỏ dấu `#` trước lệnh `quit` ở
cuối script.

## 6. Các biến điều khiển synthesis

Top module:

```tcl
set DESIGN picorv32
```

Effort của ba giai đoạn:

```tcl
set SYN_EFFORT medium
set MAP_EFFORT medium
set OPT_EFFORT medium
```

Có thể đổi `medium` thành effort level được phiên bản Genus đang dùng hỗ trợ.
Effort cao hơn thường tăng runtime và bộ nhớ nhưng không đảm bảo kết quả tốt
hơn trong mọi thiết kế.

Số CPU tối đa:

```tcl
set_db max_cpus_per_server 8
```

Cần giảm giá trị này nếu máy hoặc license không cho phép sử dụng 8 CPU.

## 7. Nạp MMMC và physical library

MMMC được nạp bằng:

```tcl
read_mmmc $MMMC_FILE
```

`mmmc.view` tạo:

- `slow_libset` từ slow Liberty.
- `fast_libset` từ fast Liberty.
- `slow_setup_view` cho setup.
- `fast_hold_view` cho hold.
- Constraint mode `functional` đọc `constraints/picorv32.sdc`.
- RC corner dùng QRC technology file `gpdk045.tch`.

LEF phải được đọc đúng thứ tự:

```tcl
read_physical -lefs [list \
    ${LEF_PATH}/gsclib045_tech.lef \
    ${LEF_PATH}/gsclib045_macro.lef \
]
```

Technology LEF được đọc trước để khai báo layer, via và site. Macro LEF được
đọc sau để cung cấp kích thước, pin và obstruction của standard cells.

Flow không dùng capTbl từ process khác. Chỉ thêm capTbl nếu có bảng GPDK045
được characterize đúng cho RC corner cần phân tích.

## 8. Nạp và elaborate RTL

RTL được đọc bằng:

```tcl
read_hdl ${RTL_PATH}/picorv32.v
elaborate $DESIGN
init_design
```

File `picorv32.v` chứa nhiều module nhưng `elaborate picorv32` chọn module
`picorv32` làm top.

Các parameter hiện dùng giá trị mặc định trong RTL. Muốn bật multiplier,
divider, PCPI, IRQ hoặc thay đổi cấu hình register file thì phải cấu hình
parameter trước hoặc trong quá trình elaborate, tùy cú pháp của phiên bản
Genus đang sử dụng.

## 9. Kiểm tra trước synthesis

Script chạy:

```tcl
check_design -unresolved
check_timing_intent
report_clocks
```

Mục đích:

- `check_design -unresolved`: tìm module, instance hoặc reference chưa resolve.
- `check_timing_intent`: tìm clock, endpoint hoặc constraint timing còn thiếu.
- `report_clocks`: xác nhận `core_clk` đã được tạo với chu kỳ đúng.

Các report tương ứng nằm trong `synthesis/reports/mmmc`.

Không nên tiếp tục đánh giá QoR nếu còn unresolved reference hoặc phần lớn
timing endpoint chưa được constraint.

## 10. Timing path groups

Flow tạo bốn cost group:

| Group | Đường timing |
|---|---|
| `I2C` | Input đến register |
| `R2R` | Register đến register |
| `C2O` | Register đến output |
| `I2O` | Input đến output |

Các group được tạo bằng lệnh Stylus `group_path`, giúp Genus tối ưu và báo cáo
riêng từng loại đường timing. Group liên quan tới register chỉ được tạo khi
design thực sự có register. Clock port được loại khỏi nhóm input bằng option
`all_inputs -no_clocks`. Trên Genus 25.13, `group_path` không có option
`-view`; các group được khai báo một lần và được dùng bởi các analysis view
đang hoạt động.

## 11. Ba giai đoạn synthesis

### `syn_generic`

Chuyển RTL đã elaborate thành biểu diễn logic generic, thực hiện các phép tối
ưu Boolean và kiến trúc chưa phụ thuộc hoàn toàn vào standard-cell library.

Sau bước này script ghi snapshot và report với tag `syn_generic`.

### `syn_map`

Ánh xạ logic generic vào các cell có trong slow/fast Liberty, đồng thời tối ưu
theo timing, area và design-rule constraints.

Sau bước này script ghi snapshot và report với tag `syn_map`.

### `syn_opt`

Tối ưu netlist đã map, sửa các vi phạm timing/design rule có thể sửa và chuẩn
bị dữ liệu handoff cho Innovus.

Sau bước này script ghi snapshot có option `-innovus` và report với tag
`syn_opt`.

## 12. Report cuối

Các report chính:

| File | Nội dung |
|---|---|
| `picorv32_messages.rpt` | Warning và error của Genus |
| `picorv32_gates.rpt` | Thống kê mapped cells |
| `picorv32_area.rpt` | Diện tích cell |
| `picorv32_power.rpt` | Ước lượng công suất |
| `picorv32_qor.rpt` | Tổng hợp quality of results |
| `picorv32_setup_timing.rpt` | 50 setup path của `slow_setup_view` |

Setup report được chọn bằng option `report_timing -views`. Genus 25.13 không
hỗ trợ `-view`, `-late` hoặc `-early` cho lệnh `report_timing`, và lệnh này chỉ
thực hiện setup analysis. Vì vậy không gọi `report_timing` với
`fast_hold_view`: view này chỉ active cho hold nên Genus sẽ báo `TUI-745` và
dừng script. Flow vẫn giữ `fast_hold_view` trong `mmmc.view` và xuất
`picorv32_fast_hold.sdc` để Innovus phân tích hold sau CTS, khi clock tree và
clock skew đã thực tế hơn.

Thư mục đầy đủ:

`/home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/reports/mmmc`

Ưu tiên kiểm tra theo thứ tự:

1. `picorv32_messages.rpt`.
2. `picorv32_check_design.rpt`.
3. `picorv32_check_timing_intent.rpt`.
4. `picorv32_qor.rpt`.
5. `picorv32_setup_timing.rpt`.
6. Area và power report.

## 13. Output và handoff sang Innovus

Thư mục output:

`/home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/outputs/mmmc`

Các file quan trọng:

| Output | Công dụng |
|---|---|
| `picorv32_netlist.v` | Mapped gate-level netlist |
| `picorv32_slow_setup.sdc` | SDC được xuất cho setup view |
| `picorv32_fast_hold.sdc` | SDC được xuất cho hold view |
| `picorv32.db` | Genus database cuối |
| `INVS/` | Common database handoff cho Innovus Stylus |

Database handoff được tạo bằng:

```tcl
write_db \
    -common ${OUTPUTS_PATH}/INVS \
    -design $DESIGN
```

Trong flow physical design, Innovus có thể nạp handoff bằng:

```tcl
set PROJECT_PATH           /home/icd1/workspace/RISC-V-PROCESSOR-45nm
set SYNTHESIS_OUTPUTS_PATH ${PROJECT_PATH}/synthesis/outputs/mmmc

cd $PROJECT_PATH
read_db -common ${SYNTHESIS_OUTPUTS_PATH}/INVS
```

Script Innovus phải khai báo các thư mục từ `PROJECT_PATH` theo cùng quy ước
path.

## 14. Chạy lại flow

Script không tự xóa output hoặc report cũ. Khi chạy lại, một số file có cùng
tên sẽ được Genus ghi đè hoặc cập nhật tùy loại output.

Nên lưu hoặc đổi tên kết quả quan trọng trước khi chạy lại với clock period,
parameter hay effort khác. Không so sánh hai lần chạy chỉ dựa trên log; nên
so sánh QoR, timing, area và power report tương ứng.

## 15. Lỗi thường gặp

### `genus: command not found`

Môi trường Cadence chưa được setup hoặc `PATH` chưa chứa Genus executable.

### License checkout failed

Kiểm tra license server, feature Genus và số lượng job/CPU đang sử dụng.

### Không tìm thấy Liberty, LEF, RTL hoặc SDC

Kiểm tra `PROJECT_PATH` và cấu trúc thư mục. Không thay bằng đường dẫn tương
đối vì flow được chuẩn hóa để bắt đầu tại thư mục cha của project.

### Unresolved references

Mở `picorv32_check_design.rpt`. Nếu đã thêm wrapper, SRAM hoặc peripheral thì
phải bổ sung RTL, black-box model, Liberty và LEF tương ứng.

### Unconstrained timing paths

Mở `picorv32_check_timing_intent.rpt`, sau đó cập nhật
`constraints/picorv32.sdc`. Không dùng false path chỉ để làm warning biến mất;
chỉ khai báo false path khi kiến trúc thực sự bảo đảm đường đó không cần timing.

### Timing không đạt

Kiểm tra loại path vi phạm, clock period, I/O delay, uncertainty, output load,
transition và fanout. Sau đó mới cân nhắc tăng synthesis effort hoặc thay đổi
RTL/pipeline.

### Power report thiếu độ chính xác

Power hiện là vectorless estimate nếu chưa cung cấp switching activity. Muốn
kết quả tốt hơn cần nạp SAIF/VCD hoặc khai báo activity phù hợp với workload.

## 16. Tiêu chí một lần chạy hợp lệ

Một lần synthesis chỉ nên được coi là hợp lệ khi:

- Không có fatal error.
- Không có unresolved reference.
- Clock và analysis views được tạo đúng.
- Các timing endpoint quan trọng đã được constraint.
- Netlist không chứa cell không có trong physical LEF.
- Setup/hold report được đánh giá ở view phù hợp.
- Output `INVS` được tạo đầy đủ để Innovus đọc.
- Các giả định timing, area và power đều được ghi lại cùng cấu hình RTL/SDC.
