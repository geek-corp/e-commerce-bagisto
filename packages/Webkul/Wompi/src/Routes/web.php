<?php

use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
use Illuminate\Support\Facades\Route;
use Webkul\Wompi\Http\Controllers\WompiController;

Route::group(['middleware' => ['web']], function () {
    Route::controller(WompiController::class)
        ->prefix('wompi')
        ->group(function () {
            Route::get('redirect', 'redirect')->name('wompi.redirect');

            Route::get('callback', 'callback')->name('wompi.callback');

            Route::post('webhook', 'webhook')
                ->withoutMiddleware(VerifyCsrfToken::class)
                ->name('wompi.webhook');
        });
});
