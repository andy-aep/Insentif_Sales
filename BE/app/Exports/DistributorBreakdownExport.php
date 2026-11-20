<?php

namespace App\Exports;

use Maatwebsite\Excel\Concerns\Export;
use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithEvents;
use Maatwebsite\Excel\Concerns\WithMultipleSheets;
use Maatwebsite\Excel\Concerns\WithTitle;
use Maatwebsite\Excel\Events\AfterSheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;

class DistributorBreakdownExport implements WithMultipleSheets, Export
{
    /**
     * @param  array<int, array<string, mixed>>  $cards
     */
    public function __construct(protected array $cards) {}

    public function sheets(): array
    {
        return [
            new DistributorSellInSheet($this->cards),
            new DistributorSellOutAoSheet($this->cards),
        ];
    }
}

class DistributorSellInSheet implements FromArray, ShouldAutoSize, WithEvents, WithTitle
{
    /**
     * @param  array<int, array<string, mixed>>  $cards
     */
    public function __construct(protected array $cards) {}

    public function title(): string
    {
        return 'Sell In';
    }

    public function array(): array
    {
        $rows = [
            ['No', 'Periode', 'Distributor', 'Depo', 'Brand', 'Target (Kg)', 'Realisasi (Kg)', 'Pencapaian (%)', 'Reward (Rp)'],
        ];

        $no = 1;
        foreach ($this->cards as $card) {
            $rows[] = [
                $no++,
                (string) ($card['period'] ?? '-'),
                (string) ($card['distributor_name'] ?? '-'),
                (string) ($card['depo_name'] ?? '-'),
                (string) ($card['brand_name'] ?? '-'),
                (float) ($card['sell_in_target'] ?? 0),
                (float) ($card['sell_in_real'] ?? 0),
                (float) ($card['sell_in_ach_pct'] ?? 0),
                (float) ($card['sell_in_reward'] ?? 0),
            ];
        }

        return $rows;
    }

    public function registerEvents(): array
    {
        return [
            AfterSheet::class => function (AfterSheet $event) {
                $sheet = $event->sheet->getDelegate();
                $lastRow = max($sheet->getHighestRow(), 1);
                $sheet->getStyle("A1:I1")->getFont()->setBold(true);
                $sheet->getStyle("A1:I{$lastRow}")->getBorders()->getAllBorders()->setBorderStyle(Border::BORDER_THIN);
            },
        ];
    }
}

class DistributorSellOutAoSheet implements FromArray, ShouldAutoSize, WithEvents, WithTitle
{
    /**
     * @param  array<int, array<string, mixed>>  $cards
     */
    public function __construct(protected array $cards) {}

    public function title(): string
    {
        return 'Sell Out & AO';
    }

    public function array(): array
    {
        $rows = [
            ['', '', '', '', '', '', 'Sell Out', '', '', '', 'AO', '', '', ''],
            [
                'No', 'Periode', 'Distributor', 'Depo', 'Area', 'Brand',
                'Target (Kg)', 'Realisasi (Kg)', 'Pencapaian (%)', 'Reward (Rp)',
                'Target (Toko)', 'Realisasi (Toko)', 'Pencapaian (%)', 'Reward (Rp)',
            ],
        ];

        $no = 1;
        foreach ($this->cards as $card) {
            $areas = $card['areas'] ?? [];
            foreach ($areas as $area) {
                $rows[] = [
                    $no++,
                    (string) ($card['period'] ?? '-'),
                    (string) ($card['distributor_name'] ?? '-'),
                    (string) ($card['depo_name'] ?? '-'),
                    (string) ($area['area_name'] ?? '-'),
                    (string) ($area['brand_name'] ?? ($card['brand_name'] ?? '-')),
                    (float) ($area['sell_out_target'] ?? 0),
                    (float) ($area['sell_out_real'] ?? 0),
                    (float) ($area['sell_out_ach_pct'] ?? 0),
                    (float) ($area['sell_out_reward'] ?? 0),
                    (float) ($area['ao_target'] ?? 0),
                    (float) ($area['ao_real'] ?? 0),
                    (float) ($area['ao_ach_pct'] ?? 0),
                    (float) ($area['ao_reward'] ?? 0),
                ];
            }
        }

        return $rows;
    }

    public function registerEvents(): array
    {
        return [
            AfterSheet::class => function (AfterSheet $event) {
                $sheet = $event->sheet->getDelegate();
                $sheet->mergeCells('G1:J1');
                $sheet->mergeCells('K1:N1');
                $sheet->getStyle('G1:N1')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);
                $sheet->getStyle('A1:N2')->getFont()->setBold(true);
                $lastRow = max($sheet->getHighestRow(), 2);
                $sheet->getStyle("A1:N{$lastRow}")->getBorders()->getAllBorders()->setBorderStyle(Border::BORDER_THIN);
            },
        ];
    }
}
