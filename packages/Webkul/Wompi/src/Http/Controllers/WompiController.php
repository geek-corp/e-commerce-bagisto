<?php

namespace Webkul\Wompi\Http\Controllers;

use Illuminate\Http\Request;
use Webkul\Checkout\Facades\Cart;
use Webkul\Checkout\Repositories\CartRepository;
use Webkul\Sales\Repositories\InvoiceRepository;
use Webkul\Sales\Repositories\OrderRepository;
use Webkul\Sales\Repositories\OrderTransactionRepository;
use Webkul\Sales\Transformers\OrderResource;
use Webkul\Shop\Http\Controllers\Controller;
use Webkul\Wompi\Payment\Wompi;

class WompiController extends Controller
{
    public const PAYMENT_APPROVED = 'APPROVED';

    public function __construct(
        protected CartRepository $cartRepository,
        protected OrderRepository $orderRepository,
        protected OrderTransactionRepository $orderTransactionRepository,
        protected InvoiceRepository $invoiceRepository,
        protected Wompi $wompi,
    ) {}

    /**
     * Redirect to Wompi checkout widget page.
     */
    public function redirect()
    {
        if (! $this->wompi->hasValidCredentials()) {
            session()->flash('error', trans('wompi::app.response.provide-credentials'));

            return redirect()->route('shop.checkout.cart.index');
        }

        $cart = Cart::getCart();

        if (! $cart) {
            session()->flash('error', trans('wompi::app.response.cart-not-found'));

            return redirect()->route('shop.checkout.cart.index');
        }

        $paymentData = $this->wompi->getPaymentData($cart);

        session(['wompi_reference' => $paymentData['reference']]);
        session(['wompi_cart_id' => $cart->id]);

        return view('wompi::checkout.redirect', [
            'paymentData' => $paymentData,
            'widgetUrl'   => $this->wompi->getWidgetUrl(),
            'checkoutUrl' => $this->wompi->getCheckoutUrl(),
        ]);
    }

    /**
     * Handle callback after Wompi payment (redirect from Wompi).
     */
    public function callback(Request $request)
    {
        $transactionId = $request->get('id');

        if (! $transactionId) {
            session()->flash('error', trans('wompi::app.response.invalid-transaction'));

            return redirect()->route('shop.checkout.cart.index');
        }

        try {
            $transaction = $this->wompi->getTransactionStatus($transactionId);
            $status = $transaction['data']['status'] ?? '';
            $reference = $transaction['data']['reference'] ?? '';

            $cartId = session('wompi_cart_id');

            if (! $cartId) {
                // Try to extract cart ID from reference (format: ETN-{cartId}-{timestamp})
                $parts = explode('-', $reference);
                $cartId = $parts[1] ?? null;
            }

            if (! $cartId) {
                session()->flash('error', trans('wompi::app.response.cart-not-found'));

                return redirect()->route('shop.checkout.cart.index');
            }

            $cart = $this->cartRepository->find($cartId);

            if (! $cart || ! $cart->is_active) {
                session()->flash('error', trans('wompi::app.response.cart-not-found'));

                return redirect()->route('shop.checkout.cart.index');
            }

            if ($status !== self::PAYMENT_APPROVED) {
                session()->flash('error', trans('wompi::app.response.payment-failed') . ' (Estado: ' . $status . ')');

                return redirect()->route('shop.checkout.cart.index');
            }

            Cart::setCart($cart);
            Cart::collectTotals();

            $data = (new OrderResource($cart))->jsonSerialize();

            $data['payment']['additional'] = [
                'wompi_transaction_id' => $transactionId,
                'wompi_reference'      => $reference,
                'wompi_status'         => $status,
                'wompi_payment_method' => $transaction['data']['payment_method_type'] ?? '',
            ];

            $order = $this->orderRepository->create($data);
            $this->orderRepository->update(['status' => 'processing'], $order->id);

            if ($order->canInvoice()) {
                $invoice = $this->invoiceRepository->create($this->prepareInvoiceData($order));

                $this->orderTransactionRepository->create([
                    'transaction_id' => $transactionId,
                    'status'         => self::PAYMENT_APPROVED,
                    'type'           => $order->payment->method,
                    'payment_method' => $order->payment->method,
                    'order_id'       => $order->id,
                    'invoice_id'     => $invoice->id,
                    'amount'         => $order->base_grand_total,
                    'data'           => json_encode($transaction['data']),
                ]);
            }

            Cart::deActivateCart();

            session()->forget(['wompi_reference', 'wompi_cart_id']);
            session()->flash('order_id', $order->id);
            session()->flash('success', trans('wompi::app.response.payment-success'));

            return redirect()->route('shop.checkout.onepage.success');
        } catch (\Exception $e) {
            report($e);

            session()->flash('error', trans('wompi::app.response.order-creation-failed'));

            return redirect()->route('shop.checkout.cart.index');
        }
    }

    /**
     * Handle Wompi webhook events.
     */
    public function webhook(Request $request)
    {
        $event = $request->all();

        if (! $this->wompi->verifyEventSignature($event)) {
            return response()->json(['error' => 'Invalid signature'], 401);
        }

        $eventType = $event['event'] ?? '';

        if ($eventType === 'transaction.updated') {
            $transactionData = $event['data']['transaction'] ?? [];
            $status = $transactionData['status'] ?? '';
            $reference = $transactionData['reference'] ?? '';

            if ($status === self::PAYMENT_APPROVED) {
                // Order already created via callback redirect in most cases.
                // This webhook serves as a backup confirmation.
                $parts = explode('-', $reference);
                $cartId = $parts[1] ?? null;

                if ($cartId) {
                    $cart = $this->cartRepository->find($cartId);

                    if ($cart && $cart->is_active) {
                        // Cart still active = callback didn't create order yet
                        // This is handled by the callback method, so we just log it
                        logger()->info('Wompi webhook: transaction approved for cart ' . $cartId . ', reference: ' . $reference);
                    }
                }
            }
        }

        return response()->json(['status' => 'ok'], 200);
    }

    protected function prepareInvoiceData($order)
    {
        $invoiceData = ['order_id' => $order->id];

        foreach ($order->items as $item) {
            $invoiceData['invoice']['items'][$item->id] = $item->qty_to_invoice;
        }

        return $invoiceData;
    }
}
