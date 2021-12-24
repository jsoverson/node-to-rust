fn main() {
    let booty = Treasure { dubloons: 1000 };

    let my_map = TreasureMap::new(&booty);
    let your_map = my_map.clone();
    println!("{:?}", my_map);
    println!("{:?}", your_map);
}

#[derive(Debug)]
struct Treasure {
    dubloons: u32,
}

#[derive(Clone, Debug)]
struct TreasureMap<'a> {
    treasure: &'a Treasure,
}

impl<'a> TreasureMap<'a> {
    fn new(treasure: &'a Treasure) -> Self {
        TreasureMap { treasure }
    }
}
