export interface Product {
  id: number;
  name: string;
  price: string;
  images: string[];
  description: string;
}

export const allProducts: Record<string, Product[]> = {
  valise: [
    { 
      id: 1, name: 'Original Cabin', price: '1 080', 
      images: [
        '/images/original_cabin_1.png',
        '/images/original_cabin_2.png',
        '/images/original_cabin_3.png'
      ], 
      description: 'Aluminium' 
    },
    { 
      id: 2, name: 'Classic Trunk', price: '1 480', 
      images: [
        '/images/trunk_2.png',
        '/images/trunk_1.png',
        '/images/trunk_3.png'
      ], 
      description: 'Aluminium Noir' 
    },
    { 
      id: 3, name: 'Essential Sleeve Cabin', price: '850', 
      images: [
        '/images/essential_3.png',
        '/images/essential_2.png',
        '/images/essential_1.png'
      ], 
      description: 'Polycarbonate Sage avec poche frontale' 
    },
    { 
      id: 4, name: 'Hybrid Trunk', price: '1 120', 
      images: [
        '/images/hybrid_1.png',
        '/images/hybrid_2.png',
        '/images/hybrid_3.png'
      ], 
      description: 'Polycarbonate & Aluminium - Sea Blue' 
    },
  ],
  sac: [
    { 
      id: 6, name: 'Signature Tote', price: '980', 
      images: [
        '/images/tote_1.png',
        '/images/tote_2.png',
        '/images/tote_3.png'
      ], 
      description: 'Cuir & Toile - Noir' 
    },
    { 
      id: 7, name: 'Signature Handbag', price: '1 250', 
      images: [
        '/images/signature_bag_1.png',
        '/images/signature_bag_2.png',
        '/images/signature_bag_3.png'
      ], 
      description: 'Cuir - Bordeaux Profond' 
    },
    { 
      id: 8, name: 'Never Still Backpack', price: '1 450', 
      images: [
        '/images/backpack_1.png',
        '/images/backpack_2.png',
        '/images/backpack_3.png'
      ], 
      description: 'Cuir Grainé - Gris Ardoise' 
    },
  ],
  accessoire: [
    { 
      id: 10, name: 'Aluminium Case iPhone 15 Pro', price: '120', 
      images: [
        '/images/phone_case_1.png',
        '/images/phone_case_2.png',
        '/images/phone_case_3.png'
      ], 
      description: 'Aluminium Matte - Titanium' 
    },
    { 
      id: 11, name: 'Aluminium Card Holder', price: '150', 
      images: [
        '/images/card_holder_1.png',
        '/images/card_holder_2.png',
        '/images/card_holder_3.png'
      ], 
      description: 'Aluminium Noir - Made in Italy' 
    },
    { 
      id: 12, name: 'Groove Belt', price: '280', 
      images: [
        '/images/belt_1.png',
        '/images/belt_2.png',
        '/images/belt_3.png'
      ], 
      description: 'Cuir & Aluminium - Finition Groove' 
    },
    { 
      id: 13, name: 'Rimowa x Mykita Sunglasses', price: '650', 
      images: [
        '/images/sunglasses_1.png',
        '/images/sunglasses_2.png',
        '/images/sunglasses_3.png'
      ], 
      description: 'Monture Acier Inoxydable' 
    },
  ]
}

export const getProductById = (id: number) => {
  for (const category of Object.values(allProducts)) {
    const product = category.find(p => p.id === id)
    if (product) return product
  }
  return null
}
