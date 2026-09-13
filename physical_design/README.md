# Physical design PicoRV32 — Innovus Stylus

Flow này được chuyển từ `counter_design_45nm/physical_design`, sử dụng
handoff Genus trong `synthesis/outputs/mmmc/INVS`. Chỉ dùng RC technology
`QRC_Tech/gpdk045.tch`; không nạp capTbl. Đây là flow triển khai block CPU,
chưa có SRAM, pad ring hoặc hệ thống SoC bao quanh.

## Trạng thái và điều kiện chạy

PD ở commit `e140862` đã chạy đủ 7 stage với handoff sạch scan: exported
netlist không có `SDFF*`, log không còn `IMPSP-9099`, setup WNS +2.247 ns,
hold WNS +0.001 ns, DRC bằng 0 và connectivity bằng 0. Cell area sau PD là
22862.016 µm² với 7.933 instance, density khoảng 70.071%. Fix hold bằng
`opt_post_route_area_reclaim hold_and_setup_aware` và hold target slack 10 ps
đã hiệu quả. Tuy nhiên final opt summary còn 6 real max-transition violations
trên các net data như `mem_wordsize[1]`, `decoded_imm_j[15]`,
`decoded_imm[31]`, `decoded_imm[9]`, `n_3117`, `pcpi_rs1[4]`; max-cap sạch
và còn 159 real max-fanout violations. Stage 6 đã được sửa tiếp để chạy
post-extraction DRV/timing recovery rồi extract lại trước khi report cuối;
cần rerun stage 6 đến stage 7 để xác nhận.

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
| 1_init_design.tcl | Read common DB, cấu hình OCV/CPPR và CTS/tie cells, kiểm tra input design/timing | picorv32_init |
| 2_floorplan_power.tcl | Core, pin plan, VDD/VSS ring và stripes, special route | picorv32_floorplan_power |
| 3_placement.tcl | place_opt_design, `check_design -type place`, pre-CTS setup report | picorv32_place |
| 4_cts.tcl | `check_design -type cts`, clock_opt_design, propagated clocks, setup/hold report | picorv32_post_cts |
| 5_routing.tcl | route_opt_design, post-route timing/DRV recovery, filler, ECO route và setup/hold report | picorv32_post_route |
| 6_chip_finish.tcl | RC extraction, post-extraction DRV/timing recovery, area/power, DRC/connectivity | picorv32_finish |
| 7_export.tcl | DB, netlist, DEF và SDC của slow_setup_view/fast_hold_view | picorv32_final |

Report nằm trong `physical_design/reports/mmmc/<stage>/`.
Stage 1 tạo lại các path group I2C/R2R/C2O/I2O ở global scope vì Innovus bỏ
qua path group nằm trong mode-specific SDC (`TA-976`). Sau khi nạp handoff,
stage 1 chạy hai kiểm tra Stylus trước khi ghi checkpoint:

```tcl
check_design -type [list library netlist synthesis timing \
    hierarchical assign_statements extract_rc] \
    > ${REPORT_PATH}/check_design_input.rpt
check_timing -verbose > ${REPORT_PATH}/check_timing.rpt
```

Stage 1 chỉ chạy các category hợp lệ ngay sau khi import. Thiết kế này là
single-voltage và không nạp UPF/CPF nên không chạy category `power_intent`;
việc không có power-intent file không phải lỗi của flow này. Placement và CTS
được kiểm tra đúng thời điểm ở stage 3 và stage 4. Không dùng `-type all` ở
stage 1 vì floorplan, placement, PG followpin và signoff environment chưa tồn
tại. `check_timing -verbose` kiểm tra clock và timing constraint. Phải đọc
report trước khi tiếp tục; không chấp nhận missing/unresolved cell đang được
dùng, library-view mismatch, clock thiếu constraint hoặc timing exception
không hợp lệ. `CHKLIBRARY-2` trên scan cell không được dùng có thể chấp nhận
khi exported netlist xác nhận scan count bằng 0. `no_drive` là hệ quả của mô
hình `set_input_transition` thay vì external driver cell; `ideal_clock_waveform`
là trạng thái dự kiến trước CTS.

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
Stripes Metal10 rộng 1 µm, spacing 1.5 µm, pitch giữa các bộ 20 µm. Theo
spacing table, dây rộng 1 µm chạy song song dài cần tối thiểu 1.25 µm; dùng
1.5 µm để đồng thời giữ tâm stripe trên grid/track. Các giá trị 0.4 µm và
1.0 µm trước đó đều tạo đúng 8 `MetSpc` violation ở 8 cặp stripe.
Các thông số này chưa được xác nhận bằng IR-drop/EM analysis.
Global nets được nối tới PG pins và các tín hiệu hằng; special route nối
core power rails. Signal router chịu trách nhiệm nối các top-level signal
pins, kể cả output hằng đã được global-net connection ánh xạ. Sau CTS/routing
phải kiểm tra connectivity lại.

## Lỗi kỹ thuật đã gặp và hướng xử lý

Các số liệu PD ban đầu thuộc commit `874a749`, synthesis sạch scan thuộc
`fa4c6d7` và PD sạch hold gần nhất thuộc `e140862`. Script đã thay đổi sau
lần chạy này nên phải rerun stage 6-7 trước khi dùng kết quả DRV/timing cuối.

| Mã lỗi/hiện tượng | Nguyên nhân đã xác định | Cách xử lý | Cách xác nhận |
|---|---|---|---|
| `check_design -type all` ở stage 1 báo 23 error và 7.704 warning dù full flow vẫn sạch DRC/connectivity | `-type all` gọi cả place/route/signoff checks trước khi floorplan và PG followpin được tạo. Vì vậy có 20 `IMPPP-4422` về followpin và 3 `IMPESO-*` do placement/Tempus/distributed signoff environment chưa sẵn sàng; hàng nghìn unplaced-object warning cũng là sai thời điểm. | Stage 1 chỉ kiểm tra input categories `library/netlist/synthesis/timing/hierarchical/assign_statements/extract_rc`. Chạy `place` sau placement và `cts` ngay trước CTS. | Rerun flow; `check_design_input.rpt` không còn `IMPPP-4422`/`IMPESO-*`; đọc thêm `check_design_place.rpt` và `check_design_cts.rpt`. |
| `IMPMSMV-7402` trong input check dù thiết kế không dùng multi-voltage | Category `power_intent` yêu cầu UPF/CPF, trong khi block hiện là single-voltage VDD/VSS và chủ ý không có power-intent file. Đây là lỗi do chọn sai category kiểm tra, không phải lỗi PG. | Bỏ riêng `power_intent` khỏi stage 1; không tạo UPF giả chỉ để làm sạch report. Nếu sau này có power domain, isolation hoặc level shifter thì phải thêm UPF thật và bật lại check này. | `check_design_input.rpt` không còn tool error; PG vẫn được xác nhận độc lập bằng global-net mapping, special route, DRC và connectivity. |
| `check_timing` báo 102 `no_drive` và một `ideal_clock_waveform` | Interface được mô hình bằng `set_input_transition` để dùng chung cho cả slow/fast library, không bằng một external driving cell; clock vẫn ideal trước CTS. Đây không phải missing input delay: timing category của `check_design` báo sạch. | Giữ mô hình transition/load cho block standalone. Khi có chip-level driver/receiver thật, thay bằng cell và interface timing đã characterize. | Mọi data input vẫn có min/max input delay và transition; sau CTS clock được propagated; setup/hold reports có đủ I2C/R2R/C2O/I2O paths. |
| `IMPSP-9099` xuất hiện 2 lần khi placement | Genus dùng 1.021 cell `SDFFQX1` để thực hiện mux-register trong flow functional không có scan-chain. Pattern đầu tiên là `*/SDFF*`, nhưng base-cell name không có library prefix nên query trả về rỗng; do không có nhánh báo lỗi, synthesis vẫn ghi handoff. Lần chạy `49c783a` vì vậy có 26/33 reported hold path kết thúc tại chân SI. | Query bằng `SDFF*`, `SEDFF*`, `SPDFF*`, `SRDFF*`, yêu cầu phải match base cell, đặt `.dont_use true`, rồi đếm lại netlist. Nếu còn scan instance, Genus dừng trước khi ghi Innovus handoff. Nếu dự án cần DFT thật thì thay bằng scan insertion/chain definition đầy đủ. | Synthesis `fa4c6d7` và PD `921693d` đã xác nhận scan count bằng 0; `IMPSP-9099` và endpoint SI/SE đã hết. `IMPSP-9025` “No scan chain” là dự kiến cho functional flow này. |
| Genus `CDFG-475/476`: case không parallel/full như pragma | RTL PicoRV32 upstream dùng `(* parallel_case, full_case *)` cho các one-hot decode/case. Với cấu hình parameter hiện tại, Genus chứng minh một số điều kiện có thể overlap hoặc không cover hết, nên cảnh báo rằng pragma mạnh hơn cấu trúc logic thực tế. | Không suppress và không tự xóa pragma khi chưa có regression/formal equivalence, vì thay đổi có thể ảnh hưởng decode semantics và PPA. Giữ warning được ghi nhận; trước signoff phải chạy RTL-to-gate formal equivalence và ISA regression. | Formal equivalence pass và simulation không có illegal-state mismatch; nếu chỉnh RTL thì rerun toàn bộ synthesis/PD. |
| Genus `ELABUTL-123`: 32 bit `pcpi_insn` undriven lúc elaborate | Cấu hình mặc định tắt PCPI; trước constant propagation, output bus tùy chọn chưa có driver hữu hiệu. Netlist cuối đã tie các bit `pcpi_insn` về 0. | Chấp nhận cho cấu hình PCPI-disabled nhưng phải kiểm tra netlist cuối. Nếu bật PCPI, warning này không được phép tồn tại và interface phải có logic driver thực. | Netlist hiện có `assign pcpi_insn[*] = 1'b0`; không có unresolved reference. Khi đổi parameter, chạy lại lint/check-design. |
| `NRGR-59`, `NRGR-60`, `NRGR-58`, `NRGR-62`; 372 DRC `OffGrd` trên Metal3/Metal4 | Offset trong pin file cũ là các số chia đều nhưng không nằm trên manufacturing grid 0.005 µm và routing track. NanoRoute không truy cập được chân, sau đó báo open net. | Snap top/bottom pins vào X track Metal4 và left/right pins vào Y track Metal3 trong `pins_mmmc.io`. Pin plan hiện có 409/409 pin on-track, không trùng offset trên cùng cạnh. | Log route không còn `NRGR-59/60`; `check_drc` không còn Metal3/Metal4 `OffGrd`. |
| 8 DRC `MetSpc` trên Metal10 | Hai stripe VDD/VSS rộng 1 µm chạy song song toàn chiều cao. Spacing table Metal10 yêu cầu 1.25 µm cho trường hợp width/parallel-run-length này. Giá trị 1.0 µm ở lần chạy `6ad9789` vẫn còn đúng 8 violation. | Tăng `add_stripes -spacing` lên 1.5 µm để có margin 0.25 µm và giữ tọa độ thuận grid. | Lần chạy `49c783a` xác nhận `check_drc = 0`. |
| 319 connectivity violations: 212 net không có route, 106 terminal hở, 1 VSS special-wire open | Phần lớn signal I/O pin không thể route do off-grid; signal router vì thế bỏ các net và cả output hằng ánh xạ vào VSS. | Sửa pin grid; giữ `route_special -connect core_pin` cho PG rail và để signal router nối top-level signal pins. Lần chạy `6ad9789` đã xác nhận connectivity bằng 0. | `check_connectivity` phải báo 0 violation; không chỉ dựa vào việc `route_opt_design` chạy xong. |
| `IMPSR-1254` khi special route | Thử thêm `block_pin` cho VDD/VSS nhưng block không có top-level PG pin thuộc hai net này; các I/O hiện có là signal pin. Mỗi power net tạo một warning. | Không yêu cầu `block_pin`; dùng `route_special -connect core_pin`. Nếu sau này thêm VDD/VSS ports hoặc pad ring thật, cập nhật lại connect targets theo package architecture. | Log `route_special` không còn `IMPSR-1254`; connectivity vẫn bằng 0. |
| `NREX-102: Has no routing` trên PCPI/IRQ và một số port | Với parameter mặc định, PCPI/IRQ bị tắt nên một số interface net chỉ còn một terminal hoặc không có timing path. Router không tạo dây cho net không cần kết nối; extraction vẫn phát warning tổng quát. VDD/VSS cũng không được signal RC extractor xử lý vì là PG/SRPG net. | Không che warning trước khi phân loại. So sánh với `check_connectivity`; net một terminal của tính năng bị tắt có thể chấp nhận. Nếu bật PCPI/IRQ, phải rerun synthesis và mọi net nhiều terminal tương ứng phải được route/extract. | `check_connectivity = 0`; không có timed multi-terminal net bị `Has no routing`; setup/hold report không dựa vào net chưa extract. |
| `IMPSR-4302` nói cap-table/qrcTechFile đã có trong design | MMMC RC corner đã cung cấp `gpdk045.tch`, nên Innovus bỏ thông tin RC trùng lặp trong technology LEF. Thông báo không có nghĩa flow đang dùng capTbl riêng. | Giữ duy nhất QRC technology file GPDK045; không thêm capTbl từ process/project khác. | `mmmc.view` chỉ tham chiếu `gpdk045.tch`; extraction hoàn thành bằng QRC engine. |
| Hold WNS `-0.211 ns` khi pin hở, sau khi route đủ còn `-0.050 ns` | Lần chạy `6ad9789` xác nhận worst path là C2O và đã có nhiều `DLY1X1`. Giá trị `set_output_delay -min -0.20` tự giả định receiver cần hold 0.20 ns, nhưng project standalone chưa có specification ngoài chip. Cộng uncertainty 0.10 ns làm required minimum delay thành 0.30 ns. | Dùng minimum output delay trung tính 0.00 ns cho standalone flow; khi tích hợp SoC phải thay bằng `-t_hold` từ receiver thật. Lần chạy `49c783a` không còn C2O hold violation; WNS còn lại là -0.007 ns ở R2R và chủ yếu liên quan scan cell. | Connectivity = 0 trước khi đọc `6_chip_finish/hold.rpt`; setup/hold WNS đều phải ≥ 0 với specification được chấp nhận. |
| PD sạch scan còn hold WNS khoảng -0.008 ns sau recovery | Trong run `4b9377e`, optimizer đã thêm 21 `CLKBUFX2`, resize 3 cell và thật sự đạt hold WNS/TNS bằng 0 ở density 66.285%. Bước `Hold Area Reclaim` mặc định sau đó xóa 34 instance và làm hold quay lại; đây không phải do hết placement site. | Đặt `opt_post_route_area_reclaim hold_and_setup_aware` để reclaim phải bảo toàn cả setup lẫn hold, và `opt_hold_target_slack 0.010` để có 10 ps margin trước filler/ECO route. Vẫn giữ `unfixed_hold` report. | Run `e140862` xác nhận sau extraction: hold WNS +0.001 ns, TNS 0, setup WNS +2.247 ns, DRC/connectivity bằng 0. |
| Run `e140862` còn 6 real max-transition violations sau post-route optimization | Stage 5 đã đóng setup/hold nhưng DRV vẫn còn ở các net data fanout vừa/cao: worst là `mem_wordsize[1]` với transition 0.650 ns so với limit 0.280 ns, slack -0.370 ns. Các net còn lại là `decoded_imm_j[15]`, `decoded_imm[31]`, `decoded_imm[9]`, `n_3117`, `pcpi_rs1[4]`. Đây không phải lỗi DRC/connectivity, mà là electrical/timing quality issue sau route. | Stage 6 phải extract RC trước, bỏ filler, chạy `opt_design -post_route -drv -setup -hold` với area reclaim hold/setup-aware, thêm filler lại, `route_eco`, rồi `extract_rc` lần nữa trước final reports. Nếu vẫn còn, cần buffer/resize thủ công hoặc xử lý fanout tree sớm hơn từ placement/synthesis. | Rerun stage 6-7; final opt summary và timingReports `postRoute.tran` phải báo 0 max-transition violation, trong khi setup/hold vẫn ≥ 0 và DRC/connectivity bằng 0. |
| Post-route còn 159 real max-fanout violations | SDC đặt giới hạn topology toàn design là 16; nhiều decode/reset net có 32–69 sink. `-drv` ưu tiên các giới hạn điện thực tế và không tự bảo đảm mọi `set_max_fanout`; 16 clock-tree net được report riêng, không tính vào 159 real violation. | Chưa nới/xóa constraint chỉ để làm đẹp report. Trước hết xác định giới hạn fanout có phải specification hay chỉ synthesis heuristic; nếu bắt buộc, bật fanout-load repair/buffer tree từ placement hoặc synthesis rồi rerun CTS/route. Nếu không bắt buộc, thay SDC bằng max-transition/max-cap theo Liberty và ghi rõ quyết định. | Max-transition/max-cap phải bằng 0. Max-fanout chỉ được sign off sau khi specification được xác nhận hoặc real violation bằng 0; không trộn clock net ký hiệu `C` với real violation `R`. |
| `IMPIMEX-7031` khi chạy full flow | Gọi `read_db` nhiều lần trong cùng Innovus session khi mỗi stage tự reload checkpoint. | Stage 1 dùng `read_db -common`; `run_full.tcl` giữ database trong memory qua `PD_DATABASE_LOADED`. Stage chạy độc lập mới đọc checkpoint của stage trước. | Full flow đi liên tục qua đủ `Done 1` đến `Done 7` mà không reload database. |
| `IMPCTE-290` trong fast hold view | SDC cũ dùng `set_driving_cell` với cell/library chỉ phù hợp slow view. | Dùng `set_input_transition -max/-min` cho input interface, dùng được ở cả hai MMMC view. | `read_db`/timing initialization không còn `IMPCTE-290`. |
| `TA-976` đối với path group | Path group được Genus export bên trong mode-specific SDC nhưng Innovus bỏ qua. | Tạo lại I2C/R2R/C2O/I2O ở global scope trong stage 1 sau khi nạp handoff. | Các timing report Innovus hiển thị đúng các group thay vì gom hết vào default. |
| Tool chạy hết nhưng message summary vẫn có error hoặc report vật lý khác 0 | Innovus hoàn thành script không đồng nghĩa thiết kế sạch timing/physical verification. | Luôn đọc message summary, setup/hold, DRC và connectivity report ở stage 6 trước khi chấp nhận kết quả. | Tiêu chí tối thiểu: 0 tool error, setup/hold WNS ≥ 0, DRC = 0 và connectivity = 0. |

## Playbook xử lý lỗi PD

Không sửa bằng cách suppress warning hoặc nới constraint trước khi xác định
root cause. Sau mỗi thay đổi phải chạy lại từ stage sớm nhất bị ảnh hưởng;
thay floorplan/placement thì không được chỉ rerun route.

| Nhóm vấn đề | Chẩn đoán trước | Hướng xử lý | Điều kiện đóng lỗi |
|---|---|---|---|
| Congestion | Xem congestion map/global-route overflow, hotspot theo layer, placement density cục bộ, pin access và vùng quanh macro/PG stripe. Phân biệt congestion thật với warning map cũ như `NRIG-1303`. | Giảm utilization hoặc tăng core; spread cell/macro và pin; chỉnh placement/routing blockage; dành layer hợp lý cho PG/clock; sửa pin access. Rerun placement → CTS → route, không chỉ route ECO. | Global-route overflow/hotspot về mức routable, detailed route kết thúc, DRC/open bằng 0 và timing không suy giảm ngoài target. |
| Setup violation | Đọc worst path theo từng MMMC view/path group, kiểm tra clock/IO constraint, transition/capacitance và route detour. | Tối ưu logic, resize/buffer, cải thiện placement, route timing-driven hoặc useful skew có kiểm soát. Chỉ giảm frequency/đổi IO delay khi specification cho phép. | WNS/TNS setup ≥ 0 trong mọi setup view sau extraction; max-transition/max-cap sạch. |
| Hold violation | Đọc early path, skew, uncertainty, min IO delay và `unfixed_hold`; kiểm tra tool không xóa lại delay buffer khi area reclaim. | Fix sau CTS bằng delay cell/buffer/resizing; sau route dùng extracted RC, giữ setup margin và area reclaim hold-aware. ECO thủ công chỉ khi report chỉ rõ optimizer không có legal solution. Không sửa bằng cách giảm hold uncertainty tùy ý. | WNS/TNS hold ≥ 0 trong mọi hold view sau filler, ECO route và extraction; setup/DRC/connectivity vẫn sạch. |
| PG | Kiểm tra VDD/VSS global-net mapping, followpin, ring/stripe width-spacing-pitch, via và target của `route_special`; phân loại skipped stripe do va ring. | Sửa geometry theo LEF spacing/grid, bảo đảm core rail nối ring/stripe, thêm PG port/pad target chỉ khi kiến trúc có thật. IR/EM cần activity và signoff rule deck riêng. | Không short/open PG trong DRC/connectivity; special route hoàn tất. Với tapeout còn phải pass IR-drop/EM và LVS. |
| Routing | Kiểm tra off-grid/pin access, unrouted multi-terminal nets, short/spacing/via DRC và congestion theo layer. Net một terminal của interface bị disable phải được phân loại riêng. | Snap pin về manufacturing/routing grid, sửa blockage/layer use/congestion; sau filler hoặc timing ECO luôn chạy `route_eco`. Không dùng `route_eco` để che floorplan lỗi. | Detailed-route DRC = 0, connectivity = 0, timed nets đã extract và post-route setup/hold sạch. |
| CTS | Chạy `check_design -type cts`, kiểm tra usable clock buffers/inverters, propagated clock, sink count, insertion delay, skew, transition và clock routing. | Sửa CTS cell list/NDR/route type, placement congestion hoặc clock constraint; dùng useful skew có kiểm soát. `No scan chain` là dự kiến ở functional flow, còn thiết kế DFT phải có scan definition thật. | `check_design_cts.rpt` sạch; `clock_trees.rpt`/`skew_groups.rpt` hợp lý; clock propagated, clock DRV sạch và post-CTS setup/hold đạt mục tiêu. |

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
