use std::{collections::HashMap, fs::read_to_string};

fn main() {
    let source = read_to_string("./README.md").unwrap();
    let mut files = HashMap::new();
    files.insert("README", source.clone());
    files.insert("README2", source);

    let files_ref = &mut files;
    let files_ref2 = &mut files;

    needs_mutable_ref(files_ref);
    needs_mutable_ref(files_ref2);
}

fn needs_mutable_ref(map: &mut HashMap<&str, String>) {}
