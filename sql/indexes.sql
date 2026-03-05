
CREATE INDEX IF NOT EXISTS idx_rental_customer_active 
ON rental(customer_id) 
WHERE return_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_rental_inventory_id ON rental(inventory_id);

CREATE INDEX IF NOT EXISTS idx_rental_staff_id ON rental(staff_id);

CREATE INDEX IF NOT EXISTS idx_rental_date ON rental(rental_date);

CREATE INDEX IF NOT EXISTS idx_inventory_film_id ON inventory(film_id);