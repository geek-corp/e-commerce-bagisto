<!DOCTYPE html>
<html lang="{{ app()->getLocale() }}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ __('wompi::app.redirect.redirecting') }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 400px;
            width: 100%;
        }
        .spinner {
            width: 50px; height: 50px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #1a1a2e;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        h2 { color: #333; font-size: 22px; font-weight: 600; margin: 20px 0 10px; }
        p { color: #666; font-size: 14px; line-height: 1.6; margin: 10px 0; }
        .secure-badge {
            display: inline-flex; align-items: center; gap: 8px;
            background: #f0fdf4; color: #166534;
            padding: 10px 16px; border-radius: 8px;
            font-size: 13px; font-weight: 500; margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        {!! view_render_event('bagisto.shop.wompi.redirect.before') !!}

        <div class="spinner"></div>
        <h2>{{ __('wompi::app.redirect.redirecting-to-payment') }}</h2>
        <p>{{ __('wompi::app.redirect.please-wait') }}</p>
        <div class="secure-badge">
            &#10003; {{ __('wompi::app.redirect.secure-payment') }}
        </div>
        <p style="color: #999; font-size: 12px;">{{ __('wompi::app.redirect.powered-by-wompi') }}</p>

        {!! view_render_event('bagisto.shop.wompi.redirect.after') !!}
    </div>

    <form action="{{ $checkoutUrl }}" id="wompi_form" method="GET" style="display: none;">
        <input type="hidden" name="public-key" value="{{ $paymentData['public_key'] }}">
        <input type="hidden" name="currency" value="{{ $paymentData['currency'] }}">
        <input type="hidden" name="amount-in-cents" value="{{ $paymentData['amount_in_cents'] }}">
        <input type="hidden" name="reference" value="{{ $paymentData['reference'] }}">
        <input type="hidden" name="signature:integrity" value="{{ $paymentData['signature'] }}">
        <input type="hidden" name="redirect-url" value="{{ $paymentData['redirect_url'] }}">
        <input type="hidden" name="customer-data:email" value="{{ $paymentData['customer_email'] }}">
        <input type="hidden" name="customer-data:full-name" value="{{ $paymentData['customer_name'] }}">
    </form>

    <script>
        setTimeout(function() {
            document.getElementById('wompi_form').submit();
        }, 1500);
    </script>
</body>
</html>
