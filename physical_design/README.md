# Physical design PicoRV32 — Innovus Stylus

Flow này được chuyển từ `counter_design_45nm/physical_design`, sử dụng
handoff Genus trong `synthesis/outputs/mmmc/INVS`. Chỉ dùng RC technology
`QRC_Tech/gpdk045.tch`; không nạp capTbl. Đây là flow triển khai block CPU,
chưa có SRAM, pad ring hoặc hệ thống SoC bao quanh.

## Trạng thái và điều kiện chạy

Flow đã chạy đủ 7 stage bằng Innovus Stylus trong commit `874a749`. Lần chạy
đó hoàn tất export và setup timing dương, nhưng chưa đạt signoff vì pin I/O
off-grid gây DRC/connectivity violation và netlist dùng scan cell trong flow
không có DFT. Pin plan, khoảng cách stripe và special-route đã được sửa; cần
chạy lại synthesis rồi chạy lại toàn bộ PD để xác nhận report mới.

Máy chạy cần Innovus/license, Liberty, LEF, QRC và database synthesis đầy đủ.
Phải chạy lại synthesis để handoff mới không dùng `SDFF*` trong flow
functional không có scan-chain. Common database chỉ dùng `gpdk045.tch` và
không còn constraint `set_driving_cell -library slow_vdd1v0` gây warning
`IMPCTE-290` trong fast hold view. Handoff chứa đường dẫn tuyệt đối từ máy
synthesis.

Mỗi script khai báo thư mục cha cố định:

```tcl
set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH
```

Các đường dẫn con dùng `${PROJECT_PATH}/...`. Nếu chuyển project sang máy
khác, sửa PROJECT_PATH trong các script PD, synthesis và mmmc.view, rồi tạo
lại handoff synthesis để cập nhật đường dẫn thư viện bên trong database.

## Chạy toàn bộ hoặc từng bước

Trên máy Cadence:

```bash
innovus -stylus -files /home/icd1/workspace/RISC-V-PROCESSOR-45nm/physical_design/run_full.tcl
```

Để kiểm tra floorplan trước khi chạy các bước tiếp theo, chạy lần lượt:

```bash
innovus -stylus -files /home/icd1/workspace/RISC-V-PROCESSOR-45nm/physical_design/1_init_design.tcl
innovus -stylus -files /home/icd1/workspace/RISC-V-PROCESSOR-45nm/physical_design/2_floorplan_power.tcl
```

Thoát phiên trước khi mở phiên tiếp theo. Trong cùng GUI cũng có thể dùng
`source` với đường dẫn tuyệt đối của script tiếp theo. Khi chạy
`run_full.tcl`, stage 1 nạp Genus handoff một lần và các stage sau tiếp tục
trên design đang ở trong memory. Khi chạy riêng một stage, script nạp
checkpoint của stage trước. Cách này tránh lỗi Innovus `IMPIMEX-7031` do gọi
`read_db` nhiều lần trong cùng session. Chạy lại một stage sẽ ghi lại output
của stage đó; lưu bản sao checkpoint nếu cần giữ phương án cũ. Flow không tự
thoát GUI.

| Script | Thao tác | Checkpoint trong outputs/mmmc |
|---|---|---|
| 1_init_design.tcl | Read common DB, cấu hình OCV/CPPR, CTS/filler/tie cells | picorv32_init |
| 2_floorplan_power.tcl | Core, pin plan, VDD/VSS ring và stripes, special route | picorv32_floorplan_power |
| 3_placement.tcl | place_opt_design, pre-CTS setup report | picorv32_place |
| 4_cts.tcl | clock_opt_design, propagated clocks, setup/hold report | picorv32_post_cts |
| 5_routing.tcl | Filler và route_opt_design, setup/hold report | picorv32_post_route |
| 6_chip_finish.tcl | RC extraction, SI timing, area/power, DRC/connectivity | picorv32_finish |
| 7_export.tcl | DB, netlist, DEF và SDC của slow_setup_view/fast_hold_view | picorv32_final |

Report nằm trong `physical_design/reports/mmmc/<stage>/`.
Stage 1 tạo lại các path group I2C/R2R/C2O/I2O ở global scope vì Innovus bỏ
qua path group nằm trong mode-specific SDC (`TA-976`).

## Floorplan, pins và power

Core khởi đầu là 180 × 181.26 µm, tương ứng 900 sites × 106 rows
CoreSite (0.2 × 1.71 µm). Với cell area synthesis 19514.520 µm²,
utilization ban đầu khoảng 59.8%, chưa tính cell CTS/tie/filler được thêm.
Margin 10 µm mỗi cạnh cho die danh nghĩa 200 × 201.26 µm.
Nếu placement congestion cao, tăng core và điều chỉnh pin offsets.

`pins_mmmc.io` chứa đủ 409 signal pins theo netlist hiện tại, phân bổ đều trên
bốn cạnh: top/bottom Metal4, left/right Metal3. Offset top/bottom nằm trên
track X của Metal4; offset left/right nằm trên track Y của Metal3. Việc snap
track này xử lý nguyên nhân của `NRGR-59/60` và Metal3/Metal4 `OffGrd` trong
lần chạy cũ. Pin plan chưa tối ưu theo kết nối memory/peripheral. Thay đổi top
ports cần cập nhật pin file; không sử dụng pin file của counter.

VDD/VSS dùng ring Metal10/Metal11 rộng 2 µm, spacing 1 µm, offset 0.6 µm.
Stripes Metal10 rộng 1 µm, spacing 1 µm, pitch giữa các bộ 20 µm. Khoảng
cách 1 µm đáp ứng spacing table của Metal10 cho dây rộng 1 µm chạy song song
dài; giá trị 0.4 µm cũ tạo đúng 8 `MetSpc` violation ở 8 bộ stripe.
Các thông số này chưa được xác nhận bằng IR-drop/EM analysis.
Global nets được nối tới PG pins và các tín hiệu hằng; special route nối
block pins và core power rails. Sau CTS/routing phải kiểm tra connectivity lại.

## Lỗi kỹ thuật đã gặp và hướng xử lý

Các số liệu dưới đây thuộc lần chạy ở commit `874a749`. Không dùng chúng làm
kết quả signoff sau khi script đã thay đổi; phải chạy lại synthesis và PD.

| Mã lỗi/hiện tượng | Nguyên nhân đã xác định | Cách xử lý | Cách xác nhận |
|---|---|---|---|
| `IMPSP-9099` xuất hiện 2 lần khi placement | Genus dùng 1.021 cell `SDFFQX1` để thực hiện mux-register trong khi flow functional không có scan-chain definition. Innovus nhận các SI/SE arc là scan chain không hoàn chỉnh. | Trong `synthesis/run_mmmc.tcl`, đặt `.dont_use true` cho các base cell `SDFF*` sau `init_design`. Phải chạy lại synthesis để tạo handoff mới trước khi chạy PD. Nếu dự án thực sự cần DFT thì bỏ cách này và thực hiện scan insertion/chain definition đầy đủ. | Netlist synthesis mới không còn instance `SDFF*`; log placement không còn `IMPSP-9099`. |
| `NRGR-59`, `NRGR-60`, `NRGR-58`, `NRGR-62`; 372 DRC `OffGrd` trên Metal3/Metal4 | Offset trong pin file cũ là các số chia đều nhưng không nằm trên manufacturing grid 0.005 µm và routing track. NanoRoute không truy cập được chân, sau đó báo open net. | Snap top/bottom pins vào X track Metal4 và left/right pins vào Y track Metal3 trong `pins_mmmc.io`. Pin plan hiện có 409/409 pin on-track, không trùng offset trên cùng cạnh. | Log route không còn `NRGR-59/60`; `check_drc` không còn Metal3/Metal4 `OffGrd`. |
| 8 DRC `MetSpc` trên Metal10 | Hai stripe VDD/VSS rộng 1 µm trong mỗi bộ chỉ cách nhau 0.4 µm. Spacing table Metal10 yêu cầu khoảng cách lớn hơn cho dây rộng và chạy song song dài. | Tăng `add_stripes -spacing` lên 1.0 µm. | `check_drc` không còn Metal10 `MetSpc`. |
| 319 connectivity violations: 212 net không có route, 106 terminal hở, 1 VSS special-wire open | Phần lớn signal I/O pin không thể route do off-grid. Các output hằng nối VSS cũng là top-level block pins nhưng special route cũ chỉ nối `core_pin`. | Sửa pin grid và dùng `route_special -connect [list block_pin core_pin]`. | `check_connectivity` phải báo 0 violation; không chỉ dựa vào việc `route_opt_design` chạy xong. |
| Hold WNS sau route/extraction là `-0.211 ns` | Các worst path là early output-delay path. Trong report cũ, net đến output pin chưa route nên wire delay bằng 0; constraint `set_output_delay -min -0.20` cùng hold uncertainty 0.10 ns tạo required hold 0.30 ns. | Không nới constraint trước khi sửa connectivity. Chạy lại với pin đã route, sau đó mới đánh giá hold và dùng post-route hold optimization nếu vẫn vi phạm. Chỉ đổi `OUTPUT_DELAY_MIN_NS` khi có timing specification của interface. | Xác nhận connectivity bằng 0 trước, rồi đọc `6_chip_finish/hold.rpt`; yêu cầu WNS ≥ 0 cho specification được chấp nhận. |
| `IMPIMEX-7031` khi chạy full flow | Gọi `read_db` nhiều lần trong cùng Innovus session khi mỗi stage tự reload checkpoint. | Stage 1 dùng `read_db -common`; `run_full.tcl` giữ database trong memory qua `PD_DATABASE_LOADED`. Stage chạy độc lập mới đọc checkpoint của stage trước. | Full flow đi liên tục qua đủ `Done 1` đến `Done 7` mà không reload database. |
| `IMPCTE-290` trong fast hold view | SDC cũ dùng `set_driving_cell` với cell/library chỉ phù hợp slow view. | Dùng `set_input_transition -max/-min` cho input interface, dùng được ở cả hai MMMC view. | `read_db`/timing initialization không còn `IMPCTE-290`. |
| `TA-976` đối với path group | Path group được Genus export bên trong mode-specific SDC nhưng Innovus bỏ qua. | Tạo lại I2C/R2R/C2O/I2O ở global scope trong stage 1 sau khi nạp handoff. | Các timing report Innovus hiển thị đúng các group thay vì gom hết vào default. |
| Tool chạy hết nhưng message summary vẫn có error hoặc report vật lý khác 0 | Innovus hoàn thành script không đồng nghĩa thiết kế sạch timing/physical verification. | Luôn đọc message summary, setup/hold, DRC và connectivity report ở stage 6 trước khi chấp nhận kết quả. | Tiêu chí tối thiểu: 0 tool error, setup/hold WNS ≥ 0, DRC = 0 và connectivity = 0. |

Lưu ý môi trường: các script cố định `PROJECT_PATH` là
`/home/icd1/workspace/RISC-V-PROCESSOR-45nm`. Nếu máy chạy không có đúng thư
mục này, cần sửa đồng bộ biến gốc trong synthesis, PD và `mmmc.view`, rồi tạo
lại Genus handoff; không sửa riêng đường dẫn con hoặc dùng đường dẫn tương đối.

## Đánh giá và giới hạn export

Kiểm tra setup sau placement; setup và hold sau CTS, routing, extraction.
WNS/TNS synthesis không thay thế post-route STA. Stage 6 ghi DRC và
connectivity reports; script chạy hết không đồng nghĩa các report bằng zero.
Đọc và xử lý violation trước khi chấp nhận kết quả. Power là ước lượng theo
activity mà tool đang có; cần activity thực tế để đánh giá công suất.

Stage 7 xuất `picorv32_post_pnr.v`, `picorv32_post_pnr.def`, hai SDC view và
database cuối. Chưa xuất GDS vì repository thiếu standard-cell GDS và stream
map GPDK045 đã xác minh. Không dùng map đánh số layer tự tạo từ counter để
khẳng định có GDS tapeout hợp lệ. Khi có PDK assets phù hợp mới cấu hình
stream-out và merge cell GDS. Metal fill, foundry DRC/LVS, IR/EM và formal
equivalence chưa được thực hiện bởi flow này.
