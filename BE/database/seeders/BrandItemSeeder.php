<?php

namespace Database\Seeders;

use App\Models\Brand;
use App\Models\BrandItem;
use Illuminate\Database\Seeder;

class BrandItemSeeder extends Seeder
{
    public function run(): void
    {
        $mapping = [
            'KAPAL' => [
                'B15', 'B1000.B', 'B1000', 'B1003', 'B13', 'B13.B', 'B15.B', 'B28', 'B5M',
                'C56.B', 'C58', 'B10', 'FB26', 'FB26.B', 'FB28', 'FB5M', 'FC56', 'FC56.B',
                'FC58', 'HB26', 'HB28', 'HB5M', 'HC56', 'HC58', 'B26', 'C56', 'B26.B',
            ],
            'GARAMI' => [
                'A08', 'A08.B', 'A07',
            ],
            'GARAMKU' => [
                'G18', 'G18.B', 'G19', 'G19.B', 'G45', 'G45.B', 'G45F', 'G90', 'G90.B', 'G91', 'G91.B',
            ],
            'JEMPOL' => [
                'D10', 'D10.B', 'D22', 'D22.B', 'D25', 'D25.B', 'D30', 'D30.B', 'FD22', 'FD22.B',
                'FD25', 'FD30', 'FD30.B', 'HD22', 'HD22.B', 'HD25', 'HD30', 'HD30.B',
            ],
            'TANGAN' => [
                'A5M', 'A26',
            ],
            'LAYAR' => [
                'D05', 'D06',
            ],
            'LEGIES' => [
                'L26', 'L5M',
            ],
        ];

        foreach ($mapping as $brandCode => $items) {
            $brand = Brand::firstOrCreate(
                ['code' => $brandCode],
                ['name' => $brandCode]
            );

            foreach ($items as $itemCode) {
                BrandItem::updateOrCreate(
                    ['item_code' => strtoupper(trim($itemCode))],
                    ['brand_id' => $brand->id]
                );
            }
        }
    }
}
