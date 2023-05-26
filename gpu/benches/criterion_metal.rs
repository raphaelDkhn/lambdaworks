use std::ops::Range;

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion};
use lambdaworks_gpu::metal::{abstractions::state::MetalState, fft::ops::gen_twiddles};
use lambdaworks_math::field::traits::RootsConfig;

use crate::util::{rand_vec, F};

mod functions;
mod util;

const SIZE_ORDERS_FFT: Range<u64> = 21..24;
const SIZE_ORDERS_MSM: Range<u64> = 1..10;

fn fft_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("Ordered FFT");

    for (order, input) in SIZE_ORDERS_FFT.zip(SIZE_ORDERS_FFT.map(util::rand_field_elements)) {
        let metal_state = MetalState::new(None).unwrap();
        let twiddles = gen_twiddles::<F>(order, RootsConfig::BitReverse, &metal_state).unwrap();

        group.throughput(criterion::Throughput::Elements(input.len() as u64));
        group.bench_with_input(
            "Parallel (Metal)",
            &(input, twiddles),
            |bench, (input, twiddles)| {
                bench.iter_with_large_drop(|| {
                    functions::metal::ordered_fft(input, twiddles);
                });
            },
        );
    }

    group.finish();
}

fn twiddles_generation_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("FFT twiddles generation");

    for order in SIZE_ORDERS_FFT {
        group.throughput(criterion::Throughput::Elements(1 << (order - 1)));
        group.bench_with_input("Parallel (Metal)", &order, |bench, order| {
            bench.iter_with_large_drop(|| {
                functions::metal::twiddles_generation(*order);
            });
        });
    }

    group.finish();
}

fn bitrev_permutation_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("Bit-reverse permutation");

    for input in SIZE_ORDERS_FFT.map(util::rand_field_elements) {
        group.throughput(criterion::Throughput::Elements(input.len() as u64));
        group.bench_with_input("Parallel (Metal)", &input, |bench, input| {
            bench.iter_with_large_drop(|| {
                functions::metal::bitrev_permute(input);
            });
        });
    }

    group.finish();
}

fn poly_evaluation_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("Polynomial");

    for poly in SIZE_ORDERS_FFT.map(util::rand_poly) {
        group.throughput(criterion::Throughput::Elements(
            poly.coefficients().len() as u64
        ));
        group.bench_with_input("evaluate_fft_metal", &poly, |bench, poly| {
            bench.iter_with_large_drop(|| {
                functions::metal::poly_evaluate_fft(poly);
            });
        });
    }

    group.finish();
}

fn poly_interpolation_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("Polynomial");

    for evals in SIZE_ORDERS_FFT.map(util::rand_field_elements) {
        group.throughput(criterion::Throughput::Elements(evals.len() as u64));
        group.bench_with_input("interpolate_fft_metal", &evals, |bench, evals| {
            bench.iter_with_large_drop(|| {
                functions::metal::poly_interpolate_fft(evals);
            });
        });
    }

    group.finish();
}

pub fn msm_benchmarks(c: &mut Criterion) {
    let mut group = c.benchmark_group("Multi-scalar Multiplication");
    let window_sizes = vec![1, 2, 4, 8, 12];

    for window_size in window_sizes {
        for order in SIZE_ORDERS_MSM {
            let (cs, hidings) = (rand_vec(order), rand_vec(order));

            group.throughput(criterion::Throughput::Elements(1 << order));

            group.bench_with_input(
                BenchmarkId::new("Parallel Pippenger (Metal)", window_size),
                &(cs, hidings),
                |bench, (cs, hidings)| {
                    bench.iter(|| {
                        functions::metal::msm(&cs, &hidings, window_size);
                    });
                },
            );
        }
    }

    group.finish();
}

criterion_group!(
    name = metal;
    config = Criterion::default().sample_size(10);
    targets =
        msm_benchmarks,
        fft_benchmarks,
        twiddles_generation_benchmarks,
        bitrev_permutation_benchmarks,
        poly_evaluation_benchmarks,
        poly_interpolation_benchmarks,
);

criterion_main!(metal);
