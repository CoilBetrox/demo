package com.example.rdtr.demo.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.rdtr.demo.entity.Estudiante;

@Repository
public interface EstudianteRepository extends JpaRepository<Estudiante, Long> {
    Optional<Estudiante> findByEmail(String email);
    List<Estudiante> findByActivoTrue();
    List<Estudiante> findByCarrera(String carrera);
    boolean existsByEmail(String email);
}
