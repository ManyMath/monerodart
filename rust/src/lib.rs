use monero_serai::{
    wallet::{
        seed::{Seed, Language},
        address::{AddressType, AddressMeta, AddressSpec, MoneroAddress, Network, SubaddressIndex},
        ViewPair,
    },
};

use rand_core::OsRng; // For generating a seed.
use zeroize::{Zeroizing};
use std::os::raw::{c_char};
use std::ffi::CString;
use std::ffi::CStr;

use curve25519_dalek::{
    edwards::EdwardsPoint,
    scalar::Scalar,
    constants::ED25519_BASEPOINT_TABLE,
};

use sha3::{Digest, Keccak256}; // For generating the view key.

/// Generates a mnemonic in the specified language
#[no_mangle]
pub extern "C" fn generate_mnemonic(language: u8) -> *const c_char {
    // Convert language int to Language struct.
    let _language: Language = match language{
        0=>Language::German,
        1=>Language::English,
        2=>Language::Spanish,
        3=>Language::French,
        4=>Language::Italian,
        5=>Language::Dutch,
        6=>Language::Portuguese,
        7=>Language::Russian,
        8=>Language::Chinese,
        9=>Language::Japanese,
        10=>Language::Esperanto,
        11=>Language::Lojban,
        12=>Language::EnglishOld,
        _=>Language::English,
    };

    // Convert/cast and return.
    let ptr: *const c_char = convert_zeroize_string_to_c_char_ptr(&Seed::to_string(&Seed::new(&mut OsRng, _language)));
    ptr
}



/// Generates an address from a mnemonic
#[no_mangle]
pub extern "C" fn generate_address(
    mnemonic: *const c_char,
    network: u8,
    account: u32,
    index: u32,
) -> *const c_char {
    let seed = match Seed::from_string(Zeroizing::new(convert_c_char_ptr_to_string(mnemonic))) {
        Ok(seed) => seed,
        Err(_) => {
            // Handle invalid mnemonic, return empty string or error code.
            return CString::new("").unwrap().into_raw();
        }
    };

    let _network: Network = match network{
        0=>Network::Mainnet,
        1=>Network::Testnet,
        2=>Network::Stagenet,
        _=>Network::Mainnet,
        // etc...
    };

    // Calculate spend key and point.
    let spend: [u8; 32] = *seed.entropy();
    let spend_scalar: Scalar = Scalar::from_bytes_mod_order(spend);
    let spend_point: EdwardsPoint = &spend_scalar * &ED25519_BASEPOINT_TABLE;

    // Calculate view key and point.
    let view: [u8; 32] = Keccak256::digest(&spend).into();
    let view_scalar: Scalar = Scalar::from_bytes_mod_order(view);
    let view_point: EdwardsPoint = &view_scalar * &ED25519_BASEPOINT_TABLE;

    let address: MoneroAddress;
    if (account == 0) && (index == 0) {
        // Public wallet address.
        address = MoneroAddress::new(
            AddressMeta::new(_network, AddressType::Standard),
            spend_point,
            view_point,
        );
    } else {
        // Public wallet subaddress at (account, index).
        let view: ViewPair = ViewPair::new(spend_point, Zeroizing::new(view_scalar));
        address = view.address(_network, AddressSpec::Subaddress(SubaddressIndex::new(account, index).unwrap()));
    }

    // Convert/cast.
    let c_string = CString::new(address.to_string()).unwrap(); // TODO validate address
    let ptr: *const c_char = c_string.as_ptr() as *const c_char;

    // Do not clean memory; must be freed by Dart wrapper.
    std::mem::forget(c_string); // Warning: memory leak! must free this memory once done with it.

    // Return.
    ptr
}

fn convert_zeroize_string_to_c_char_ptr(zeroized_string: &str) -> *const c_char {
    // Convert the zeroized string to a normal string.
    let rust_string = zeroized_string;

    // Convert the string to a CString.
    let c_string = CString::new(rust_string).expect("Failed to create CString");

    // Convert the CString to a raw pointer.
    let raw_ptr = c_string.into_raw();

    // Return the raw pointer.
    raw_ptr
}


fn convert_c_char_ptr_to_string(c_char_ptr: *const c_char) -> String {
    // Make sure c_char_ptr isn't null.
    let c_str: &CStr = unsafe {
        assert!(!c_char_ptr.is_null());
        CStr::from_ptr(c_char_ptr)
    };

    // Convert and return.
    c_str.to_string_lossy().into_owned()
}

// TODO: Add tests.
