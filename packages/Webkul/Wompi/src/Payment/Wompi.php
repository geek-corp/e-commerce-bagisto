<?php

namespace Webkul\Wompi\Payment;

use Illuminate\Support\Facades\Storage;
use Webkul\Checkout\Facades\Cart;
use Webkul\Payment\Payment\Payment;

class Wompi extends Payment
{
    protected $code = 'wompi';

    public function getRedirectUrl()
    {
        return route('wompi.redirect');
    }

    public function isAvailable()
    {
        return parent::isAvailable() && $this->hasValidCredentials();
    }

    public function getTitle()
    {
        return $this->getConfigData('title') ?? trans('wompi::app.title');
    }

    public function getDescription()
    {
        return $this->getConfigData('description') ?? trans('wompi::app.description');
    }

    public function getImage()
    {
        $url = $this->getConfigData('image');

        return $url ? Storage::url($url) : '';
    }

    public function isSandbox()
    {
        return (bool) ($this->getConfigData('sandbox') ?? env('WOMPI_SANDBOX', true));
    }

    public function getPublicKey()
    {
        return $this->getConfigData('public_key') ?: env('WOMPI_PUBLIC_KEY');
    }

    public function getPrivateKey()
    {
        return $this->getConfigData('private_key') ?: env('WOMPI_PRIVATE_KEY');
    }

    public function getIntegrityKey()
    {
        return $this->getConfigData('integrity_key') ?: env('WOMPI_INTEGRITY_KEY');
    }

    public function getEventsKey()
    {
        return $this->getConfigData('events_key') ?: env('WOMPI_EVENTS_KEY');
    }

    public function getApiUrl()
    {
        return $this->isSandbox()
            ? 'https://sandbox.wompi.co/v1'
            : 'https://production.wompi.co/v1';
    }

    public function getCheckoutUrl()
    {
        return 'https://checkout.wompi.co/p/';
    }

    public function getWidgetUrl()
    {
        return 'https://checkout.wompi.co/widget.js';
    }

    /**
     * Generate integrity signature.
     * Formula: SHA256(reference + amount_in_cents + currency + integrity_key)
     */
    public function generateSignature($reference, $amountInCents, $currency = 'COP')
    {
        $concatenated = $reference . $amountInCents . $currency . $this->getIntegrityKey();

        return hash('sha256', $concatenated);
    }

    /**
     * Get acceptance token from Wompi API.
     */
    public function getAcceptanceToken()
    {
        $response = file_get_contents($this->getApiUrl() . '/merchants/' . $this->getPublicKey());

        $data = json_decode($response, true);

        return $data['data']['presigned_acceptance']['acceptance_token'] ?? null;
    }

    /**
     * Check transaction status via API.
     */
    public function getTransactionStatus($transactionId)
    {
        $url = $this->getApiUrl() . '/transactions/' . $transactionId;

        $context = stream_context_create([
            'http' => [
                'header' => "Authorization: Bearer {$this->getPrivateKey()}\r\n",
            ],
        ]);

        $response = file_get_contents($url, false, $context);

        return json_decode($response, true);
    }

    /**
     * Verify webhook event signature.
     * Concatenate property values + timestamp + events_key, then SHA256.
     */
    public function verifyEventSignature(array $event)
    {
        $properties = $event['signature']['properties'] ?? [];
        $checksum = $event['signature']['checksum'] ?? '';
        $timestamp = $event['timestamp'] ?? '';

        $concatenated = '';

        foreach ($properties as $property) {
            $value = data_get($event, 'data.transaction.' . $property, data_get($event, 'data.' . $property, ''));
            $concatenated .= $value;
        }

        $concatenated .= $timestamp . $this->getEventsKey();

        return hash('sha256', $concatenated) === $checksum;
    }

    /**
     * Prepare payment data for the checkout widget.
     */
    public function getPaymentData($cart = null)
    {
        if (! $cart) {
            $cart = Cart::getCart();
        }

        $reference = 'ETN-' . $cart->id . '-' . time();
        $amountInCents = (int) round($cart->grand_total * 100);
        $currency = 'COP';

        return [
            'public_key'     => $this->getPublicKey(),
            'currency'       => $currency,
            'amount_in_cents' => $amountInCents,
            'reference'      => $reference,
            'signature'      => $this->generateSignature($reference, $amountInCents, $currency),
            'redirect_url'   => route('wompi.callback'),
            'customer_email' => $cart->customer_email,
            'customer_name'  => $cart->customer_first_name . ' ' . $cart->customer_last_name,
        ];
    }

    public function hasValidCredentials()
    {
        return ! empty($this->getPublicKey())
            && ! empty($this->getIntegrityKey());
    }
}
