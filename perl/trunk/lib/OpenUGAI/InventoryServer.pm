package OpenUGAI::InventoryServer;

use strict;
use Carp;
use XML::Serializer;
use OpenUGAI::Util;
use OpenUGAI::Data::Inventory;

our %RestHandlers = (
		     "GetInventory" => \&_get_inventory,
		     "CreateInventory" => \&_create_inventory,
		     "NewFolder" => \&_new_folder,
		     "MoveFolder" => \&_move_folder,
		     "NewItem" => \&_new_item,
		     "DeleteItem" => \&_delete_item,
		     "RootFolders" => \&_root_folders,
		     "UpdateFolder" => \&_update_folder,
		     "PurgeFolder" => \&_purge_folder,
		     );
sub StartUp {
    # for mod_perl startup
    ;
}

sub DispatchRestHandler {
    my ($methodname, @param) = @_; # @param is extracted by xmlrpc lib
    &OpenUGAI::Util::Log("inventory", "Dispatch", $methodname);
    if ($RestHandlers{$methodname}) {
	return $RestHandlers{$methodname}->(@param);
    }
    Carp::croak("unknown rest method");
}

# #################
# Handlers
sub _get_inventory {
    my $post_data = shift;
    my $request_obj = &OpenUGAI::Util::XML2Obj($post_data);
    &OpenUGAI::Util::Log("inventory", "get_inventory_request", $request_obj);

    # secure inventory, but do nothing for now
    #&_validate_session($request_obj);

    my $uuid = $request_obj->{Body};
    my $inventry_folders = &OpenUGAI::Data::Inventory::getUserInventoryFolders($uuid);
    my @response_folders = ();
    foreach (@$inventry_folders) {
	my $folder = &_convert_to_response_folder($_);
	push @response_folders, $folder;
    }
    my $inventry_items = &OpenUGAI::Data::Inventory::getUserInventoryItems($uuid);
    my @response_items = ();
    foreach (@$inventry_items) {
	my $item = &_convert_to_response_item($_);
	push @response_items, $item;
    }
    my $response_obj = { # TODO much duplicated data ***
	Folders => { InventoryFolderBase => \@response_folders },
	UserID => { Guid => $uuid },
	Items => { InventoryItemBase => \@response_items },
    };

    &OpenUGAI::Util::Log("inventory", "get_inventory_response", $response_obj);

    my $serializer = new XML::Serializer( $response_obj, "InventoryCollection");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

sub _create_inventory {
    my $post_data = shift;
    my $uuid = &_get_uuid($post_data);
    my $InventoryFolders = &_create_default_inventory($uuid);
    foreach (@$InventoryFolders) {
	&OpenUGAI::Data::Inventory::saveInventoryFolder($_);
    }
    my $serializer = new XML::Serializer("true", "boolean");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

sub _update_folder {
    # TODO @@@ copy from _new_folder, but "replace into" does not work everywhere
    my $post_data = shift;
    my $request_obj = &OpenUGAI::Util::XML2Obj($post_data);
    my $folder = &_convert_to_db_folder($request_obj->{Body});
    &OpenUGAI::Data::Inventory::saveInventoryFolder($folder);
    my $serializer = new XML::Serializer("true", "boolean");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

sub _new_folder {
    my $post_data = shift;
    my $request_obj = &OpenUGAI::Util::XML2Obj($post_data);
    my $folder = &_convert_to_db_folder($request_obj->{Body});
    &OpenUGAI::Data::Inventory::saveInventoryFolder($folder);
    my $serializer = new XML::Serializer("true", "boolean");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

sub _move_folder {
    my $post_data = shift;
    my $request_obj = &OpenUGAI::Util::XML2Obj($post_data);
    &OpenUGAI::Data::Inventory::moveInventoryFolder($request_obj->{Body});
    my $serializer = new XML::Serializer("true", "boolean");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

sub _purge_folder {
    my $post_data = shift;
    my $request_obj = &OpenUGAI::Util::XML2Obj($post_data);
    &OpenUGAI::Data::Inventory::purgeInventoryFolder($request_obj->{Body});
    my $serializer = new XML::Serializer("true", "boolean");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

sub _new_item {
    my $post_data = shift;
    # TODO @@@ check inventory id
    my $request_obj = &OpenUGAI::Util::XML2Obj($post_data);
    &OpenUGAI::Util::Log("inventory", "new_item", $request_obj);

    my $item = &_convert_to_db_item($request_obj->{Body});
    &OpenUGAI::Data::Inventory::saveInventoryItem($item);
    my $serializer = new XML::Serializer("true", "boolean");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

sub _delete_item {
    my $post_data = shift;
    my $request_obj = &OpenUGAI::Util::XML2Obj($post_data);
    my $item = $request_obj->{Body};
    my $item_id = $item->{ID}->{Guid};
    &OpenUGAI::Data::Inventory::deleteInventoryItem($item_id);
    my $serializer = new XML::Serializer("true", "boolean");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

sub _root_folders {
    my $post_data = shift;
    my $uuid = &_get_uuid($post_data);
    my $response = undef;
    my $inventory_root_folder = &OpenUGAI::Data::Inventory::getRootFolder($uuid);
    if ($inventory_root_folder) {
	my $root_folder_id = $inventory_root_folder->{folderID};
	my $root_folder = &_convert_to_response_folder($inventory_root_folder);
	my $root_folders = &OpenUGAI::Data::Inventory::getChildrenFolders($root_folder_id);
	my @folders = ($root_folder);
	foreach(@$root_folders) {
	    my $folder = &_convert_to_response_folder($_);
	    push @folders, $folder;
	}
	$response = { InventoryFolderBase => \@folders };
    } else {
	$response = { InventoryFolderBase => &_create_default_inventory($uuid, 1) };
    }
    my $serializer = new XML::Serializer($response, "ArrayOfInventoryFolderBase");
    return $serializer->to_formatted(XML::Serializer::WITH_HEADER); # TODO:
}

# #################
# subfunctions
sub _convert_to_db_item {
    my $item = shift;
    my $ret = {
	assetID => $item->{AssetID}->{Guid},
	assetType => $item->{AssetType},
	inventoryBasePermissions => $item->{BasePermissions} || 0,
	creationDate => $item->{CreationDate} || time,
	creatorID => $item->{CreatorId}, # TODO ??? $item->{CreatorIdAsUuid}->{Guid}
	inventoryCurrentPermissions => $item->{CurrentPermissions},
	inventoryDescription => ref($item->{Description}) ? "" : $item->{Description},
	inventoryEveryOnePermissions => $item->{EveryOnePermissions} || 0,
	flags => $item->{Flags},
	parentFolderID => $item->{Folder}->{Guid},
	groupID => $item->{GroupID}->{Guid},
	groupOwned => ($item->{GroupOwned} == "false") ? 0 : 1,
	inventoryGroupPermissions => $item->{GroupPermissions} || 0,
	inventoryID => $item->{ID}->{Guid}, # TODO @@@ this can not be null
	invType => $item->{InvType} || 0,
      	inventoryName => $item->{Name},
	inventoryNextPermissions => $item->{NextPermissions},
	avatarID => $item->{Owner}->{Guid},
	salePrice => $item->{SalePrice},
	saleType => $item->{SaleType},
    };
    return $ret;
}

sub _convert_to_response_item {
    my $item = shift;
    my $ret = {
	ID => { Guid => $item->{inventoryID} },
	AssetID => { Guid => $item->{assetID} },
	AssetType => $item->{assetType},
	InvType => $item->{invType},
	Folder => { Guid => $item->{parentFolderID} },
	Owner => { Guid => $item->{avatarID} },
	Creator => { Guid => $item->{creatorID} },
	Name => $item->{inventoryName},
	Description => $item->{inventoryDescription} || "",
	NextPermissions => $item->{inventoryNextPermissions},
	CurrentPermissions => $item->{inventoryCurrentPermissions},
	BasePermissions => $item->{inventoryBasePermissions},
	EveryOnePermissions => $item->{inventoryEveryOnePermissions},
	CreationDate => $item->{creationDate},
	Flags => $item->{flags},
	GroupID => $item->{groupID},
	GroupOwned => $item->{groupOwned},
	SalePrice => $item->{salePrice},
	SaleType => $item->{saleType},
    };
    return $ret;
}

sub _convert_to_db_folder {
    my $folder = shift;
    my $ret = {
	folderName => $folder->{Name},
	agentID => $folder->{Owner}->{Guid},
	parentFolderID => $folder->{ParentID}->{Guid},
	folderID => $folder->{ID}->{Guid},
	type => $folder->{Type},
	version => $folder->{Version},
    };
    return $ret;
}

sub _convert_to_response_folder {
    my $folder = shift;
    my $ret = {
	Name => $folder->{folderName},
	Owner => { Guid => $folder->{agentID} },
	ParentID => { Guid => $folder->{parentFolderID} },
	ID => { Guid => $folder->{folderID} },
	Type => $folder->{type},
	Version => $folder->{version},
    };
    return $ret;
}

sub __create_folder_struct {
    my ($id, $owner, $parentid, $name, $type, $version) = @_;
    return {
	"Name" => $name,
	"Owner" => { Guid => $owner },
	"ParentID" => { Guid => $parentid },
	"ID" => { Guid => $id },
	"Type" => $type,
	"Version" => $version,
    };
}

sub _create_default_inventory {
    my ($uuid, $save_flag)= @_;
    $save_flag ||= 0;
    my @InventoryFolders = ();
    my $root_folder_id = &OpenUGAI::Util::GenerateUUID();
    push @InventoryFolders, &__create_folder_struct($root_folder_id, $uuid, &OpenUGAI::Util::ZeroUUID(), "My Inventory", 8, 1);
    push @InventoryFolders, &__create_folder_struct(&OpenUGAI::Util::GenerateUUID(), $uuid, $root_folder_id, "Textures", 0, 1);
    push @InventoryFolders, &__create_folder_struct(&OpenUGAI::Util::GenerateUUID(), $uuid, $root_folder_id, "Objects", 6, 1);
    push @InventoryFolders, &__create_folder_struct(&OpenUGAI::Util::GenerateUUID(), $uuid, $root_folder_id, "Clothes", 5, 1);
    push @InventoryFolders, &__create_folder_struct(&OpenUGAI::Util::GenerateUUID(), $uuid, $root_folder_id, "Bodyparts", 13, 1);
    if ($save_flag) {
	foreach(@InventoryFolders) {
	    &OpenUGAI::Data::Inventory::saveInventoryFolder(&_convert_to_db_folder($_));
	}
    }
    return \@InventoryFolders;
}


# #################
# Utilities
sub _get_uuid {
    my $data = shift;
    if ($data =~ /<guid\s*>([^<]+)<\/guid>/) {
	return $1;
    } else {
	Carp::croak("can not find uuid [$data]");
    }
}

sub _validate_session {
    my $data = shift;
    if (!$data->{SessionID} || !$data->{AvatarID} || !$data->{Body}) {
	Carp::croak("invalid data format");	
    }
    my $session_id = $data->{SessionID};
    my $user_id = $data->{AvatarID};
    if ( !&_check_auth_session($user_id, $session_id) ) {
	Carp::croak("invalid session id");
    }
}

sub _check_auth_session {
    # TODO @@@ not inplemented
    return 1;
}


1;
