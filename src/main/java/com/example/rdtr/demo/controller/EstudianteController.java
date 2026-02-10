package com.example.rdtr.demo.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.rdtr.demo.dto.EstudianteRequestDTO;
import com.example.rdtr.demo.dto.EstudianteResponseDTO;
import com.example.rdtr.demo.service.EstudianteService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/estudiantes")
@RequiredArgsConstructor
public class EstudianteController {

    private final EstudianteService estudianteService;

    @PostMapping
    public ResponseEntity<EstudianteResponseDTO> crearEstudiante(
            @Valid @RequestBody EstudianteRequestDTO estudianteRequestDTO) {
        EstudianteResponseDTO response = estudianteService.crearEstudiante(estudianteRequestDTO);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<EstudianteResponseDTO> obtenerEstudiante(@PathVariable Long id) {
        EstudianteResponseDTO response = estudianteService.obtenerEstudiantePorId(id);
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<EstudianteResponseDTO>> obtenerTodosLosEstudiantes() {
        List<EstudianteResponseDTO> response = estudianteService.obtenerTodosLosEstudiantes();
        return ResponseEntity.ok(response);
    }

    @GetMapping("/activos")
    public ResponseEntity<List<EstudianteResponseDTO>> obtenerEstudiantesActivos() {
        List<EstudianteResponseDTO> response = estudianteService.obtenerEstudiantesActivos();
        return ResponseEntity.ok(response);
    }

    @GetMapping("/carrera/{carrera}")
    public ResponseEntity<List<EstudianteResponseDTO>> obtenerEstudiantesPorCarrera(
            @PathVariable String carrera) {
        List<EstudianteResponseDTO> response = estudianteService.obtenerEstudiantesPorCarrera(carrera);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<EstudianteResponseDTO> actualizarEstudiante(
            @PathVariable Long id,
            @Valid @RequestBody EstudianteRequestDTO estudianteRequestDTO) {
        EstudianteResponseDTO response = estudianteService.actualizarEstudiante(id, estudianteRequestDTO);
        return ResponseEntity.ok(response);
    }

    @PatchMapping("/{id}/desactivar")
    public ResponseEntity<Void> desactivarEstudiante(@PathVariable Long id) {
        estudianteService.desactivarEstudiante(id);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminarEstudiante(@PathVariable Long id) {
        estudianteService.eliminarEstudiante(id);
        return ResponseEntity.noContent().build();
    }

}
