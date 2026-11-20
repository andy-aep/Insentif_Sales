<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class SapService
{
    /**
     * Fetch list of Sales Employees from SAP API (POST /api/ListSalesEmp).
     *
     * @return array<int, array{slp_code: int, slp_name: string}>
     */
    public function listSalesEmployees(bool $includeUnassigned = false): array
    {
        $baseUrl = rtrim((string) config('services.sap.base_url'), '/');
        if ($baseUrl === '') {
            throw new RuntimeException('SAP_API_BASE_URL belum dikonfigurasi di .env.');
        }

        $timeout = (int) config('services.sap.timeout', 15);
        $response = Http::timeout($timeout)
            ->acceptJson()
            ->withBody('{}', 'application/json')
            ->post("{$baseUrl}/api/ListSalesEmp");

        if (! $response->successful()) {
            throw new RuntimeException(
                "Gagal mengambil data Sales SAP (HTTP {$response->status()})."
            );
        }

        $payload = $response->json();
        if (! is_array($payload)) {
            throw new RuntimeException('Format respons API SAP tidak valid.');
        }

        $errorCode = (int) ($payload['ErrorCode'] ?? -1);
        if ($errorCode !== 0) {
            $msg = trim((string) ($payload['Message'] ?? 'Unknown SAP error'));
            throw new RuntimeException("API SAP Error ({$errorCode}): {$msg}");
        }

        $items = $payload['Result'] ?? [];
        if (! is_array($items)) {
            return [];
        }

        return collect($items)
            ->map(fn ($row) => [
                'slp_code' => (int) ($row['SlpCode'] ?? 0),
                'slp_name' => trim((string) ($row['SlpName'] ?? '')),
            ])
            ->filter(fn ($row) => ($includeUnassigned || $row['slp_code'] >= 0) && $row['slp_name'] !== '')
            ->sortBy('slp_name', SORT_NATURAL | SORT_FLAG_CASE)
            ->values()
            ->all();
    }

    /**
     * Fetch list of Industri Customers from SAP API (POST /api/ListCustIndustri).
     *
     * @return array<int, array<string, mixed>>
     */
    public function listIndustriCustomers(): array
    {
        $baseUrl = rtrim((string) config('services.sap.base_url'), '/');
        if ($baseUrl === '') {
            throw new RuntimeException('SAP_API_BASE_URL belum dikonfigurasi di .env.');
        }

        $timeout = (int) config('services.sap.timeout', 15);
        $response = Http::timeout($timeout)
            ->acceptJson()
            ->withBody('{}', 'application/json')
            ->post("{$baseUrl}/api/ListCustIndustri");

        if (! $response->successful()) {
            throw new RuntimeException(
                "Gagal mengambil data Customer Industri SAP (HTTP {$response->status()})."
            );
        }

        $payload = $response->json();
        if (! is_array($payload)) {
            throw new RuntimeException('Format respons API SAP tidak valid.');
        }

        $errorCode = (int) ($payload['ErrorCode'] ?? -1);
        if ($errorCode !== 0) {
            $msg = trim((string) ($payload['Message'] ?? 'Unknown SAP error'));
            throw new RuntimeException("API SAP Error ({$errorCode}): {$msg}");
        }

        $items = $payload['Result'] ?? [];
        if (! is_array($items)) {
            return [];
        }

        return collect($items)
            ->map(fn ($row) => [
                'card_code' => strtoupper(trim((string) ($row['CardCode'] ?? ''))),
                'card_name' => trim((string) ($row['CardName'] ?? '')),
                'city' => trim((string) ($row['Depo'] ?? '')),
                'address' => trim((string) ($row['Address'] ?? '')),
                'phone' => trim((string) ($row['Phone1'] ?? '')),
                'contact_person' => trim((string) ($row['CntctPrsn'] ?? '')),
                'group_code' => $row['GroupCode'] ?? null,
            ])
            ->filter(fn ($row) => $row['card_code'] !== '' && $row['card_name'] !== '')
            ->sortBy('card_name', SORT_NATURAL | SORT_FLAG_CASE)
            ->values()
            ->all();
    }

    /**
     * Fetch Sell-In Industri realization from SAP API (POST /api/ListSellinIndustri).
     *
     * @return array<int, array<string, mixed>>
     */
    public function listSellinIndustri(string $period, ?int $slpCode = null, ?string $cardCode = null): array
    {
        $baseUrl = rtrim((string) config('services.sap.base_url'), '/');
        if ($baseUrl === '') {
            throw new RuntimeException('SAP_API_BASE_URL belum dikonfigurasi di .env.');
        }

        $body = ['Period' => trim($period)];
        if ($slpCode !== null) {
            $body['SlpCode'] = $slpCode;
        }
        if ($cardCode !== null && trim($cardCode) !== '') {
            $body['CardCode'] = strtoupper(trim($cardCode));
        }

        $timeout = (int) config('services.sap.timeout', 15);
        $response = Http::timeout($timeout)
            ->acceptJson()
            ->post("{$baseUrl}/api/ListSellinIndustri", $body);

        if (! $response->successful()) {
            throw new RuntimeException(
                "Gagal mengambil data Realisasi Industri SAP (HTTP {$response->status()})."
            );
        }

        $payload = $response->json();
        if (! is_array($payload)) {
            throw new RuntimeException('Format respons API SAP tidak valid.');
        }

        $errorCode = (int) ($payload['ErrorCode'] ?? -1);
        if ($errorCode !== 0) {
            $msg = trim((string) ($payload['Message'] ?? 'Unknown SAP error'));
            throw new RuntimeException("API SAP Error ({$errorCode}): {$msg}");
        }

        $items = $payload['Result'] ?? [];
        if (! is_array($items)) {
            return [];
        }

        return collect($items)
            ->map(function ($row) use ($period) {
                $docPeriod = trim((string) ($row['Period'] ?? $period));
                $docDate = isset($row['DocDate']) && trim((string) $row['DocDate']) !== ''
                    ? substr(trim((string) $row['DocDate']), 0, 10)
                    : null;

                return [
                    'period' => $docPeriod,
                    'sap_so_no' => trim((string) ($row['SapSoNo'] ?? '')),
                    'doc_date' => $docDate,
                    'card_code' => strtoupper(trim((string) ($row['CardCode'] ?? ''))),
                    'card_name' => trim((string) ($row['CardName'] ?? '')),
                    'group_code' => $row['GroupCode'] ?? null,
                    'slp_code' => isset($row['SlpCode']) ? (int) $row['SlpCode'] : null,
                    'slp_name' => trim((string) ($row['SlpName'] ?? '')),
                    'volume_kg' => (float) ($row['VolumeKg'] ?? 0),
                    'nominal' => (float) ($row['Nominal'] ?? 0),
                    'is_noo' => array_key_exists('IsNoo', $row) ? filter_var($row['IsNoo'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) : null,
                    'first_tx_period' => isset($row['FirstTxPeriod']) ? trim((string) $row['FirstTxPeriod']) : null,
                ];
            })
            ->filter(fn ($row) => $row['card_code'] !== '' && $row['volume_kg'] > 0)
            ->values()
            ->all();
    }

    /**
     * Fetch Sell-In Distributor realization from SAP API (POST /api/ListSellinDistributor).
     *
     * @param  array<int, string>|null  $cardCodes
     * @return array<int, array<string, mixed>>
     */
    public function listSellinDistributor(
        ?string $period = null,
        ?string $dateFrom = null,
        ?string $dateTo = null,
        ?string $cardCode = null,
        ?array $cardCodes = null,
        ?int $slpCode = null
    ): array {
        $baseUrl = rtrim((string) config('services.sap.base_url'), '/');
        if ($baseUrl === '') {
            throw new RuntimeException('SAP_API_BASE_URL belum dikonfigurasi di .env.');
        }

        $body = [];
        if ($period !== null && trim($period) !== '') {
            $body['Period'] = trim($period);
        }
        if ($dateFrom !== null && trim($dateFrom) !== '') {
            $body['DateFrom'] = trim($dateFrom);
        }
        if ($dateTo !== null && trim($dateTo) !== '') {
            $body['DateTo'] = trim($dateTo);
        }
        if ($cardCode !== null && trim($cardCode) !== '') {
            $body['CardCode'] = strtoupper(trim($cardCode));
        }
        if (! empty($cardCodes)) {
            $body['CardCodes'] = array_values(array_unique(array_map(
                fn ($c) => strtoupper(trim((string) $c)),
                $cardCodes
            )));
        }
        if ($slpCode !== null) {
            $body['SlpCode'] = $slpCode;
        }

        $timeout = (int) config('services.sap.timeout', 15);
        $response = Http::timeout(max($timeout, 30))
            ->acceptJson()
            ->post("{$baseUrl}/api/ListSellinDistributor", $body ?: new \stdClass());

        if (! $response->successful()) {
            throw new RuntimeException(
                "Gagal mengambil data Sell-In Distributor SAP (HTTP {$response->status()})."
            );
        }

        $payload = $response->json();
        if (! is_array($payload)) {
            throw new RuntimeException('Format respons API SAP tidak valid.');
        }

        $errorCode = (int) ($payload['ErrorCode'] ?? -1);
        if ($errorCode !== 0) {
            $msg = trim((string) ($payload['Message'] ?? 'Unknown SAP error'));
            throw new RuntimeException("API SAP Error ({$errorCode}): {$msg}");
        }

        $items = $payload['Result'] ?? [];
        if (! is_array($items)) {
            return [];
        }

        return collect($items)
            ->map(function ($row) use ($period) {
                $docDate = isset($row['DocDate']) && trim((string) $row['DocDate']) !== ''
                    ? substr(trim((string) $row['DocDate']), 0, 10)
                    : null;
                $docPeriod = trim((string) ($row['Period'] ?? ''));
                if ($docPeriod === '' && $docDate !== null && strlen($docDate) >= 7) {
                    $docPeriod = str_replace('-', '', substr($docDate, 0, 7));
                }
                if ($docPeriod === '' && $period !== null) {
                    $docPeriod = trim($period);
                }

                return [
                    'period' => $docPeriod,
                    'doc_date' => $docDate,
                    'sap_doc_no' => trim((string) ($row['SapDocNo'] ?? '')),
                    'card_code' => strtoupper(trim((string) ($row['CardCode'] ?? ''))),
                    'card_name' => trim((string) ($row['CardName'] ?? '')),
                    'item_code' => strtoupper(trim((string) ($row['ItemCode'] ?? ''))),
                    'item_name' => trim((string) ($row['ItemName'] ?? '')),
                    'slp_code' => isset($row['SlpCode']) ? (int) $row['SlpCode'] : null,
                    'slp_name' => trim((string) ($row['SlpName'] ?? '')),
                    'volume_kg' => (float) ($row['VolumeKg'] ?? 0),
                    'nominal' => (float) ($row['Nominal'] ?? 0),
                ];
            })
            ->filter(fn ($row) => $row['card_code'] !== '' && $row['volume_kg'] != 0.0)
            ->values()
            ->all();
    }
}
