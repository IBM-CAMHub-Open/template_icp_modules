output "image_load_finished" { 
    value = "${null_resource.image_load_finished.id}" 
    description="Output Parameter when Module Complete"
}