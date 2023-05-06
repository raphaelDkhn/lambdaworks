use super::utils::{
    generate_domain, generate_permutation_coefficients, FrElement, FrField,
    ORDER_R_MINUS_1_ROOT_UNITY,
};
use crate::setup::{CommonPreprocessedInput, Witness};
use lambdaworks_math::polynomial::Polynomial;
use serde::{Deserialize, Serialize};

// The json exported in go comes with Uppercase in the first letter.
#[allow(non_snake_case)]
#[derive(Serialize, Deserialize)]
struct JsonPlonkCircuit {
    N: usize,
    Omega: String,
    N_padded: usize,
    Input: Vec<String>,
    Ql: Vec<String>,
    Qr: Vec<String>,
    Qm: Vec<String>,
    Qo: Vec<String>,
    Qc: Vec<String>,
    A: Vec<String>,
    B: Vec<String>,
    C: Vec<String>,
    Permutation: Vec<usize>,
}

pub fn common_preprocessed_input_from_json(
    json_string: &str,
) -> (
    Witness<FrField>,
    CommonPreprocessedInput<FrField>,
    Vec<FrElement>,
) {
    let json_input: JsonPlonkCircuit = serde_json::from_str(json_string).unwrap();
    let n = json_input.N_padded;
    let omega = FrElement::from_hex(&json_input.Omega);
    let domain = generate_domain(&omega, n);
    let permuted = generate_permutation_coefficients(&omega, n, &json_input.Permutation);

    let pad = FrElement::from_hex(&json_input.Input[0]);

    let s1_lagrange: Vec<FrElement> = permuted[..n].to_vec();
    let s2_lagrange: Vec<FrElement> = permuted[n..2 * n].to_vec();
    let s3_lagrange: Vec<FrElement> = permuted[2 * n..].to_vec();
    (
        Witness {
            a: process_vector(json_input.A, &pad, n),
            b: process_vector(json_input.B, &pad, n),
            c: process_vector(json_input.C, &pad, n),
        },
        CommonPreprocessedInput {
            n,
            domain: domain.clone(),
            omega,
            k1: ORDER_R_MINUS_1_ROOT_UNITY,
            ql: Polynomial::interpolate(
                &domain,
                &process_vector(json_input.Ql, &FrElement::zero(), n),
            ),
            qr: Polynomial::interpolate(
                &domain,
                &process_vector(json_input.Qr, &FrElement::zero(), n),
            ),
            qo: Polynomial::interpolate(
                &domain,
                &process_vector(json_input.Qo, &FrElement::zero(), n),
            ),
            qm: Polynomial::interpolate(
                &domain,
                &process_vector(json_input.Qm, &FrElement::zero(), n),
            ),
            qc: Polynomial::interpolate(
                &domain,
                &process_vector(json_input.Qc, &FrElement::zero(), n),
            ),
            s1: Polynomial::interpolate(&domain, &s1_lagrange),
            s2: Polynomial::interpolate(&domain, &s2_lagrange),
            s3: Polynomial::interpolate(&domain, &s3_lagrange),
            s1_lagrange,
            s2_lagrange,
            s3_lagrange,
        },
        convert_str_vec_to_frelement_vec(json_input.Input),
    )
}

pub fn pad_vector<'a>(
    v: &'a mut Vec<FrElement>,
    p: &FrElement,
    target_size: usize,
) -> &'a mut Vec<FrElement> {
    v.append(&mut vec![p.clone(); target_size - v.len()]);
    v
}

fn convert_str_vec_to_frelement_vec(ss: Vec<String>) -> Vec<FrElement> {
    ss.iter().map(|s| FrElement::from_hex(s)).collect()
}

fn process_vector(vector: Vec<String>, pad: &FrElement, n: usize) -> Vec<FrElement> {
    pad_vector(&mut convert_str_vec_to_frelement_vec(vector), pad, n).to_owned()
}

#[cfg(test)]
mod tests {
    use super::common_preprocessed_input_from_json;

    #[test]
    fn test_import_gnark_circuit_from_json() {
        common_preprocessed_input_from_json(
            r#"{
 "N": 4,
 "N_padded": 4,
 "Omega": "8d51ccce760304d0ec030002760300000001000000000000",
  "Input": [
  "2",
  "4"
 ],
 "Ql": [
  "73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000",
  "73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000",
  "0",
  "1"
 ],
 "Qr": [
  "0",
  "0",
  "0",
  "73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000"
 ],
 "Qm": [
  "0",
  "0",
  "1",
  "0"
 ],
 "Qo": [
  "0",
  "0",
  "73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000",
  "0"
 ],
 "Qc": [
  "0",
  "0",
  "0",
  "0"
 ],
 "A": [
  "2",
  "4",
  "2",
  "4"
 ],
 "B": [
  "2",
  "2",
  "2",
  "4"
 ],
 "C": [
  "2",
  "2",
  "4",
  "2"
 ],
 "Permutation": [
  11,
  3,
  2,
  1,
  0,
  4,
  5,
  10,
  6,
  8,
  7,
  9
 ]
}"#,
        );
    }
}