// This file mostly exists in order to just test functionality via `cargo run`

use monero_serai::{
    // random_scalar,
    rpc::{HttpRpc},
    wallet::{
        // ViewPair, Scanner,
        // address::{AddressError, Network, AddressType, AddressSpec, AddressMeta, MoneroAddress},
        // SpendableOutput,
        seed::{Seed, Language},
        address::{AddressType, AddressMeta, AddressSpec, MoneroAddress, Network, SubaddressIndex},
        Scanner,
        ViewPair,
    },
};
// use monero_serai::*;

use rand_core::OsRng; // for generating a random seed

use curve25519_dalek::{
    edwards::EdwardsPoint,
    scalar::Scalar,
    constants::ED25519_BASEPOINT_TABLE,
};

use sha3::{Digest, Keccak256}; // for generating the view key

use zeroize::Zeroizing;

use std::collections::HashSet;

use tokio; // for async main

#[tokio::main]
async fn main() {
    // address generation test vectors
    test_address_generation();
    // TODO refactor into proper `cargo test`able tests with assertions ... pull vectors out into some struct (or json)

    // output detection example WIP
    test_output_detection().await;
}

fn test_address_generation() {
    println!("\nRunning checks on test vector...");
    // test vector from https://xmrtests.llcoins.net/addresstests.html
    // seed (mnemonic): hemlock jubilee eden hacksaw boil superior inroads epoxy exhale orders cavernous second brunt saved richly lower upgrade hitched launching deepest mostly playful layout lower eden
    // seed (hex): 29adefc8f67515b4b4bf48031780ab9d071d24f8a674b879ce7f245c37523807
    // private spend: 29adefc8f67515b4b4bf48031780ab9d071d24f8a674b879ce7f245c37523807
    // private view: 3bc0b202cde92fe5719c3cc0a16aa94f88a5d19f8c515d4e35fae361f6f2120e
    // private view (audit address): 4f02594e84985fd78b91bb25dbb184d673b96b8b7539cc648c9c95a095428400
    // public spend: 72170da1793490ea9d0243df46c515444c35104b92b1d75a7d8c5954ba1f49cd
    // public view: 21243cb8d0046baf10619d1fe7f38708095b006ef8e8350963c160478c1c0ff0
    // address: 45wsWad9EwZgF3VpxQumrUCRaEtdyyh6NG8sVD3YRVVJbK1jkpJ3zq8WHLijVzodQ22LxwkdWx7fS2a6JzaRGzkNU8K2Dhi
    // subaddress: 86QMPxju4EHGHZfyswVHXsQcKK3vJgqUFgbP8Xx8DNTSjaGqcp8KXc9isQS3Hh8twz8huegagK19rJLDbBwCwAxRHX4vcv5
    digest_mnemonic("hemlock jubilee eden hacksaw boil superior inroads epoxy exhale orders cavernous second brunt saved richly lower upgrade hitched launching deepest mostly playful layout lower eden", &Network::Mainnet);

    // example random seed generation:
    println!("\nRunning generation example...");
    // roundabout way to get a random mnemonic
    let seed = &Seed::new(&mut OsRng, Language::English);
    let mnemonic = &Seed::to_string(seed);
    digest_mnemonic(mnemonic.as_str(), &Network::Mainnet);

    // stagenet example
    println!("\nRunning stagenet example...");
    // https://monero.stackexchange.com/a/8767
    // Address: 55LTR8KniP4LQGJSPtbYDacR7dz8RBFnsfAKMaMuwUNYX6aQbBcovzDPyrQF9KXF9tVU6Xk3K8no1BywnJX6GvZX8yJsXvt
    // Seeds: vocal either anvil films dolphin zeal bacon cuisine quote syndrome rejoices envy okay pancakes tulips lair greater petals organs enmity dedicated oust thwart tomorrow tomorrow
    // Secret view key: 0a1a38f6d246e894600a3e27238a064bf5e8d91801df47a17107596b1378e501
    // Public view key: eedc5c8d9e3b0a8963c04fa980e4cbaa31ac5c427e21f841a7e93f279aa2fa46
    // Secret spend key: 722bbfcf99a9b2c9e700ce857850dd8c4c94c73dca8d914c603f5fee0e365803
    // Public spend key: 5c8044a93a0d4b73fdd9698b1c8935d3bcae206e26590ce425c2085e2fb81db3
    digest_mnemonic("vocal either anvil films dolphin zeal bacon cuisine quote syndrome rejoices envy okay pancakes tulips lair greater petals organs enmity dedicated oust thwart tomorrow tomorrow", &Network::Stagenet);
    // block 76415 c9102b88b764591c613403f3c1ecf5d14a2929ce49b9e22257a925a25b84d0ef has coinbase tx c6c25a04dc01391875a9f845f03652798caea0772fb033615a1b2963731bfbef, 31.354865430195

    println!("\nRunning alternate stagenet example...");
    // alternate vector: honked bagpipe alpine juicy faked afoot jostle claim cowl tunnel orphans negative pheasants feast jetting quote frown teeming cycling tribal womanly hills cottage daytime daytime
    // address: 58aWiYGUeqZc5idYcx31rYR58K1EVsCYkN6thrZppU1MGqMowPh1BYy4frVWH5RjGLPWthZy9sRGm5ZC4fgX44HUCmqtGUf
    // subaddress: 75fvgGHHE1aAqex6Pq51hu9vG4GJd9zbsRKHxZymPa9xNPwNkK5g16idhG1Qn8C9eGdAGPXZ4E8Cz1gsotu3AynFVFBGca6
    digest_mnemonic("honked bagpipe alpine juicy faked afoot jostle claim cowl tunnel orphans negative pheasants feast jetting quote frown teeming cycling tribal womanly hills cottage daytime daytime", &Network::Stagenet);
}

fn digest_mnemonic(mnemonic: &str, network: &Network) {
    let seed = Seed::from_string(Zeroizing::new(mnemonic.to_string())).unwrap();
    println!("Seed (mnemonic): {:?}", Seed::to_string(&seed).as_str());
    let spend: [u8; 32] = *seed.entropy();
    println!("Private spend key: {:?}", hex::encode(spend));
    let spend_scalar = Scalar::from_bytes_mod_order(spend);
    let spend_point: EdwardsPoint = &spend_scalar * &ED25519_BASEPOINT_TABLE;
    let view: [u8; 32] = Keccak256::digest(&spend).into();
    let view_scalar = Scalar::from_bytes_mod_order(view);
    println!("Private view key: {:?}", hex::encode(view_scalar.to_bytes()));
    let view_point: EdwardsPoint = &view_scalar * &ED25519_BASEPOINT_TABLE;
    let address = MoneroAddress::new(
        AddressMeta::new(*network, AddressType::Standard),
        spend_point,
        view_point,
    );
    println!("Public address: {:?}", address.to_string());
    // TODO: find out why this doesn't work/match
    // let subaddress = MoneroAddress::new(
    //     AddressMeta::new(*network, AddressType::Subaddress),
    //     spend_point,
    //     view_point,
    // );
    // println!("Subaddress: {:?}", subaddress.to_string());
    let view = ViewPair::new(spend_point, Zeroizing::new(view_scalar));
    // let view_address = view.address(network, AddressSpec::Standard);
    // assert view_address = _address
    let view_subaddress = view.address(*network, AddressSpec::Subaddress(SubaddressIndex::new(0, 1).unwrap()));
    // AddressSpec::Subaddress(SubaddressIndex::new(0, 1).unwrap())
    println!("Subaddress(0, 1): {:?}", view_subaddress.to_string());
}

async fn test_output_detection() {
    println!("\nRunning output detection example...");
    // let network: Network = Network::Stagenet;
    let seed = Seed::from_string(Zeroizing::new("honked bagpipe alpine juicy faked afoot jostle claim cowl tunnel orphans negative pheasants feast jetting quote frown teeming cycling tribal womanly hills cottage daytime daytime".to_string())).unwrap();
    let spend: [u8; 32] = *seed.entropy();
    let spend_scalar = Scalar::from_bytes_mod_order(spend);
    let spend_point: EdwardsPoint = &spend_scalar * &ED25519_BASEPOINT_TABLE;
    let view: [u8; 32] = Keccak256::digest(&spend).into();
    let view_scalar = Scalar::from_bytes_mod_order(view);
    // let view_point: EdwardsPoint = &view_scalar * &ED25519_BASEPOINT_TABLE;
    // let address = MoneroAddress::new(
    //     AddressMeta::new(network, AddressType::Standard),
    //     spend_point,
    //     view_point,
    // );
    let view = ViewPair::new(spend_point, Zeroizing::new(view_scalar));

    let mut scanner = Scanner::from_view(view.clone(), Some(HashSet::new()));
    scanner.register_subaddress(SubaddressIndex::new(0, 1).unwrap());
    // let rpc = rpc().await;
    // let start = rpc.get_height().await.unwrap();
    // let rpc = HttpRpc::new("http://127.0.0.1:38081".to_string()).unwrap(); // for local stagenet daemon testing
    let rpc = HttpRpc::new("http://stagenet.community.rino.io:38081".to_string()).unwrap(); // for remote stagenet daemon testing
    // let rpc = HttpRpc::new("https://monero.stackwallet.com:18081".to_string()).unwrap(); // for remote mainnet testing
    // let height = rpc.get_height().await.unwrap();
    // println!("Block height: {:?}", height.to_string());
    // block 1384526 a5918cf3adadfabee8675011d574aa5cea619d7cedd62a58bd81d391dc4234db has tx 07a561e60118c0a485b20bbfac787fd8efead96a9f422d9dff4a86f2985db7c5, 10.000000000000 XMR to 58aWiYGUeqZc5idYcx31rYR58K1EVsCYkN6thrZppU1MGqMowPh1BYy4frVWH5RjGLPWthZy9sRGm5ZC4fgX44HUCmqtGUf
    let block = rpc.get_block_by_number(1384526).await.unwrap(); // looking for a 10
    // scanner.scan(rpc, &block).await.unwrap().swap_remove(0).ignore_timelock().swap_remove(0)
    let scan = scanner.scan(&rpc, &block).await.unwrap().swap_remove(0).ignore_timelock().swap_remove(0);
    // println!("Address scan result: {:?}", scan);
    println!("Address scan result: detected output {:?}:{:?}, {:?} XMR", hex::encode(scan.output.absolute.tx), scan.output.absolute.o, scan.output.data.commitment.amount);
    // assert hex::encode(scan.output.absolute.tx) = 07a561e60118c0a485b20bbfac787fd8efead96a9f422d9dff4a86f2985db7c5
    // block 1385227 1136a5aeb0c952753c74a411f61f3a184c42491494cc562435b269ea91d992b1 has tx d3a1e2cadfeed4868a3175667fd4bb35dbd9bf8a1fa583b5545ec4737905e3ac, 5.000000000000 XMR to 75fvgGHHE1aAqex6Pq51hu9vG4GJd9zbsRKHxZymPa9xNPwNkK5g16idhG1Qn8C9eGdAGPXZ4E8Cz1gsotu3AynFVFBGca6
    // let block = rpc.get_block_by_number(1385227).await.unwrap(); // looking for a 10
    // block 1385233 1aed4f97379f5267c63f54bbeadb6a1325f0966935e87aef1674df1c202af785 has tx d8008ba2da5fd2360da4ff819d03ba4da13ae0283ee26f34c7a5eda185563942, 420.000000000000 XMR to 75fvgGHHE1aAqex6Pq51hu9vG4GJd9zbsRKHxZymPa9xNPwNkK5g16idhG1Qn8C9eGdAGPXZ4E8Cz1gsotu3AynFVFBGca6
    // TODO figure out how to get multiple outputs, this is picking up our own coinbase tx (I had to mine to get this tx confirmed :P)
    // block 1385271 6a8b22fe5b48f2b183492ac4750cf0d9058a3822041b8778ce70c9a1842577cb has tx fdb44c6c645e21b8ec64e7412b5ab1cf661a7ad6c2a3f8a3077e6a8d87ded210, 420.000000000000 XMR to 75fvgGHHE1aAqex6Pq51hu9vG4GJd9zbsRKHxZymPa9xNPwNkK5g16idhG1Qn8C9eGdAGPXZ4E8Cz1gsotu3AynFVFBGca6
    let block = rpc.get_block_by_number(1385271).await.unwrap();
    // let scan = scanner.scan(&rpc, &block).await.unwrap().swap_remove(0).ignore_timelock().swap_remove(0);
    let scan = scanner.scan(&rpc, &block).await.unwrap().swap_remove(0).ignore_timelock().swap_remove(0);
    // println!("Subaddress scan result: {:?}", scan);
    println!("Subaddress scan result: detected output {:?}:{:?}, {:?} XMR", hex::encode(scan.output.absolute.tx), scan.output.absolute.o, scan.output.data.commitment.amount);
    // assert hex::encode(scan.output.absolute.tx) = fdb44c6c645e21b8ec64e7412b5ab1cf661a7ad6c2a3f8a3077e6a8d87ded210
}

// pub async fn rpc() -> Rpc<HttpRpc> {
//     let rpc = HttpRpc::new("http://127.0.0.1:38081".to_string()).unwrap();
//
//     // Only run once
//     if rpc.get_height().await.unwrap() != 1 {
//         return rpc;
//     }
//
//     // Make sure we recognize the protocol
//     rpc.get_protocol().await.unwrap();
//
//     rpc
// }

#[cfg(test)]
mod tests {
    // use super::*;

    #[test]
    fn it_works() {
        // TODO
    }
}
