## @fileoverview 메인 메뉴 씬 스크립트. 타이틀 화면과 게임 시작 진입점을 관리한다.
extends Control


## 시작 버튼 클릭 시 호출
func _on_start_button_pressed() -> void:
	# TODO: 실제 게임 씬으로 전환
	print("게임 시작!")


## 종료 버튼 클릭 시 호출
func _on_quit_button_pressed() -> void:
	get_tree().quit()
