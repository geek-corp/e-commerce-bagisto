<?php

namespace Webkul\Wompi\Providers;

use Illuminate\Support\ServiceProvider;

class WompiServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->registerConfig();
    }

    public function boot(): void
    {
        $this->loadRoutesFrom(__DIR__ . '/../Routes/web.php');

        $this->loadTranslationsFrom(__DIR__ . '/../Resources/lang', 'wompi');

        $this->loadViewsFrom(__DIR__ . '/../Resources/views', 'wompi');
    }

    protected function registerConfig(): void
    {
        $this->mergeConfigFrom(
            dirname(__DIR__) . '/Config/payment-methods.php', 'payment_methods'
        );
    }
}
