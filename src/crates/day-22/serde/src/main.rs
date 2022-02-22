use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
struct Author {
    first: String,
    last: String,
}

fn main() {
    let mark_twain = Author {
        first: "Samuel".to_owned(),
        last: "Clemens".to_owned(),
    };

    let serialized_json = serde_json::to_string(&mark_twain).unwrap();
    println!("Serialized as JSON: {}", serialized_json);
    let serialized_mp = rmp_serde::to_vec(&mark_twain).unwrap();
    println!("Serialized as MessagePack: {:?}", serialized_mp);

    let deserialized_json: Author = serde_json::from_str(&serialized_json).unwrap();
    println!("Deserialized from JSON: {:?}", deserialized_json);
    let deserialized_mp: Author = rmp_serde::from_read_ref(&serialized_mp).unwrap();
    println!("Deserialized from MessagePack: {:?}", deserialized_mp);
}
