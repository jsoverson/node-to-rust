use std::rc::Rc;

fn main() {
    let booty = Rc::new(Treasure { dubloons: 1000 });

    let my_map = TreasureMap::new(booty);
    let your_map = my_map.clone();
    println!("{:?}", my_map);
    println!("{:?}", your_map);
}

#[derive(Debug)]
struct Treasure {
    dubloons: u32,
}

#[derive(Clone, Debug)]
struct TreasureMap {
    treasure: Rc<Treasure>,
}

impl TreasureMap {
    fn new(treasure: Rc<Treasure>) -> Self {
        TreasureMap { treasure }
    }
}
