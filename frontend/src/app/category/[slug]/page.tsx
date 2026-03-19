"use client";
import React from 'react';
import { useRouter, useParams } from 'next/navigation';
import { allProducts } from '@/data/products';
import '../Category.css';

export default function Category() {
  const router = useRouter();
  const params = useParams();
  
  const categoryName = Array.isArray(params.slug) ? params.slug[0] : params.slug || 'valise';
  
  const products = allProducts[categoryName.toLowerCase()] || [];

  const formatCategoryTitle = (slug: string) => {
    const titles: Record<string, string> = {
      valise: 'Valises',
      sac: 'Sacs & Bagages',
      accessoire: 'Accessoires'
    };
    return titles[slug.toLowerCase()] || slug;
  };

  const goToProduct = (id: number) => {
    router.push(`/product/${id}`);
  };

  return (
    <div className="category-page">
      <div className="header-spacing"></div>

      <div className="page-title reveal-up">
        <h1 className="title-text">{formatCategoryTitle(categoryName)}</h1>
        <div className="gold-bar"></div>
      </div>

      <div className="product-grid">
        {products.map((product, index) => (
          <div 
            key={product.id}
            className={`product-card delay-${(index % 4 + 1) * 100} reveal-up`}
            onClick={() => goToProduct(product.id)}
          >
            <div className="product-image">
              <img src={product.images[0]} alt={product.name} className="main-img" />
              {product.images[1] && (
                <img src={product.images[1]} alt={product.name + ' detail'} className="hover-img" />
              )}
              <div className="quick-view">Découvrir</div>
            </div>
            <div className="product-info">
              <h3>{product.name}</h3>
              <p className="desc">{product.description}</p>
              <p className="price">{product.price} €</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
