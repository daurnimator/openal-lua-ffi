-- FFI binding to OpenAL

local rel_dir = assert ( debug.getinfo ( 1 , "S" ).source:match ( [=[^@(.-[/\]?)[^/\]*$]=] ) , "Current directory unknown" ) .. "./"

local assert , error = assert , error
local setmetatable = setmetatable
local getenv = os.getenv

local ffi 					= require"ffi"
local ffi_util 				= require"ffi_util"
local ffi_add_include_dir 	= ffi_util.ffi_add_include_dir
local ffi_defs 				= ffi_util.ffi_defs
local ffi_process_defines 	= ffi_util.ffi_process_defines

assert ( jit , "jit table unavailable" )
local openal_lib
if jit.os == "Windows" then
	local basedir = getenv ( [[ProgramFiles(x86)]] ) or getenv ( [[ProgramFiles]] )
	basedir = basedir .. [[\OpenAL 1.1 SDK\]]

	ffi_add_include_dir ( basedir .. [[include\]] )
	openal_lib = ffi.load ( [[OpenAL32]] )
elseif jit.os == "Linux" or jit.os == "OSX" or jit.os == "POSIX" or jit.os == "BSD" then
	ffi_add_include_dir [[/usr/include/AL/]]
	openal_lib = ffi.load ( [[libopenal]] )
else
	error ( "Unknown platform" )
end

ffi_defs ( rel_dir .. [[al_defs.h]] , {
		[[al.h]] ;
		[[alc.h]] ;
	} )

local openal_defs = {}
ffi_process_defines( [[al.h]] , openal_defs )
ffi_process_defines( [[alc.h]], openal_defs )


local openal = setmetatable ( { } , { __index = function ( t , k ) return openal_defs[k] or openal_lib[k] end ; } )

-- Some variables to be used temporarily
local int = ffi.new ( "ALint[1]" )
local uint = ffi.new ( "ALuint[1]" )
local float = ffi.new ( "ALfloat[1]" )

openal.sourcetypes = {
	[openal_defs.AL_STATIC] 		= "static" ;
	[openal_defs.AL_STREAMING] 		= "streaming" ;
	[openal_defs.AL_UNDETERMINED] 	= "undetermined" ;
}

openal.format = {
	MONO8 			= openal_defs.AL_FORMAT_MONO8 ;
	MONO16 			= openal_defs.AL_FORMAT_MONO16 ;
	STEREO8 		= openal_defs.AL_FORMAT_STEREO8 ;
	STEREO16 		= openal_defs.AL_FORMAT_STEREO16 ;
	MONO_FLOAT32 	= openal.alGetEnumValue ( "AL_FORMAT_MONO_FLOAT32" ) ;
	STEREO_FLOAT32 	= openal.alGetEnumValue ( "AL_FORMAT_STEREO_FLOAT32" ) ;
	["QUAD16"] 		= openal.alGetEnumValue ( "AL_FORMAT_QUAD16" ) ;
	["51CHN16"] 	= openal.alGetEnumValue ( "AL_FORMAT_51CHN16" ) ;
	["61CHN16"] 	= openal.alGetEnumValue ( "AL_FORMAT_61CHN16" ) ;
	["71CHN16"] 	= openal.alGetEnumValue ( "AL_FORMAT_71CHN16" ) ;
}
-- Make table work in reverse too
for k , v in pairs ( openal.format ) do openal.format [ v ] = k end

openal.format_to_channels = {
	MONO8 			= 1 ;
	MONO16 			= 1 ;
	STEREO8 		= 2 ;
	STEREO16 		= 2 ;
	MONO_FLOAT32 	= 1 ;
	STEREO_FLOAT32 	= 2 ;
	["QUAD16"] 		= 4 ;
	["51CHN16"] 	= 6 ;
	["61CHN16"] 	= 7 ;
	["71CHN16"] 	= 8 ;
}

openal.format_to_type = {
	MONO8 			= "int8_t" ;
	MONO16 			= "int16_t" ;
	STEREO8 		= "int8_t" ;
	STEREO16 		= "int16_t" ;
	MONO_FLOAT32 	= "float" ;
	STEREO_FLOAT32 	= "float" ;
	["QUAD16"] 		= "int16_t" ;
	["51CHN16"] 	= "int16_t" ;
	["61CHN16"] 	= "int16_t" ;
	["71CHN16"] 	= "int16_t" ;
}

--[[openal.type_to_scale = {
	["int8_t"] = 		2^(8-1)-1 ;
	["int16_t"] = 		2^(16-1)-1 ;
	["float"] = 		1 ;
}--]]

openal.errormsg = {
	AL_NO_ERROR 			= "No Error." ;
	AL_INVALID_NAME 		= "Invalid Name paramater passed to AL call." ;
	AL_ILLEGAL_ENUM 		= "Invalid parameter passed to AL call." ;
	AL_INVALID_VALUE 		= "Invalid enum parameter value." ;
	AL_INVALID_OPERATION 	= "Illegal call." ;
	AL_OUT_OF_MEMORY 		= "Out of memory." ;
}

openal.error = {
	[openal_defs.AL_NO_ERROR] 			= "AL_NO_ERROR" ;
	[openal_defs.AL_INVALID_NAME] 		= "AL_INVALID_NAME" ;
	[openal_defs.AL_ILLEGAL_ENUM] 		= "AL_ILLEGAL_ENUM" ;
	[openal_defs.AL_INVALID_VALUE] 		= "AL_INVALID_VALUE" ;
	[openal_defs.AL_INVALID_OPERATION] 	= "AL_INVALID_OPERATION" ;
	[openal_defs.AL_OUT_OF_MEMORY] 		= "AL_OUT_OF_MEMORY" ;
}


local function al_checkerr ( )
	local e = openal.alGetError ( )
	local ename = openal.error [ e ]
	if ename == "AL_NO_ERROR" then
		return true
	else
		return false , ename
	end
end

local function al_assert ( lvl )
	lvl = lvl or 1
	local ok , ename = al_checkerr ( )
	if ok then
		return ok
	else
		local emsg = openal.errormsg [ ename ]
		return error ( ename .. ": " .. emsg , lvl )
	end
end
openal.assert = al_assert

function openal.opendevice ( name )
	local dev = assert ( openal.alcOpenDevice ( name ) , "Can't Open Device" )
	ffi.gc ( dev , function ( dev ) print("GC DEVICE") return openal.alcCloseDevice(dev) end )
	return dev
end

--Wrappers around current context functions as in ffi, equivalent pointers...aren't.
local current_context = openal.alcGetCurrentContext ( )
function openal.alcMakeContextCurrent ( ctx )
	current_context = ctx
	openal_lib.alcMakeContextCurrent ( ctx )
	al_assert ( )
end

function openal.alcGetCurrentContext ( ctx )
	return current_context
end

local ctx_to_device = setmetatable ( { } , { __mode = "k" } )
local function ctx_gc ( ctx )
	print("GC CONTEXT")
	ctx_to_device [ ctx ] = nil
	if ctx == current_context then
		openal_lib.alcMakeContextCurrent ( nil )
	end
	openal.alcDestroyContext ( ctx )
end
function openal.newcontext ( dev )
	local ctx = ffi.gc ( assert ( openal.alcCreateContext ( dev , nil ) , "Can't create context" ) , ctx_gc )
	ctx_to_device [ ctx ] = dev
	return ctx
end

function openal.getvolume ( )
	openal.alGetListenerf ( openal_defs.AL_GAIN , float )
	al_assert ( )
	return float[0]
end

function openal.setvolume ( v )
	openal.alListenerf ( openal_defs.AL_GAIN , v )
	al_assert ( )
end

--- OpenAL Source
local source_methods = { }
local source_mt = { __index = source_methods }
function openal.newsource ( )
	openal.alGenSources ( 1 , uint )
	local s = setmetatable ( { id = uint[0] , ctx = current_context } , source_mt )
	return s
end

source_methods.delete = function ( s )
	print("GC SOURCE")
	uint[0] = s.id
	openal.alDeleteSources ( 1 , uint )
	al_assert ( )
end

source_methods.isvalid = function ( s )
	local r = openal.alIsSource ( s.id )
	al_assert ( )
	if r == 1 then return true
	elseif r == 0 then return false
	else error()
	end
end

source_methods.buffers_queued = function ( s )
	openal.alGetSourcei ( s.id , openal_defs.AL_BUFFERS_QUEUED , int )
	al_assert ( )
	return int[0]
end

source_methods.buffers_processed = function ( s )
	openal.alGetSourcei ( s.id , openal_defs.AL_BUFFERS_PROCESSED , int )
	al_assert ( )
	return int[0]
end

source_methods.type = function ( s )
	openal.alGetSourcei ( s.id , openal_defs.AL_SOURCE_TYPE , int )
	al_assert ( )
	return openal.sourcetypes [ int[0] ] or error ( "Unknown Source Type" )
end

source_methods.play = function ( s )
	openal.alSourcePlay ( s.id )
	al_assert ( )
end

source_methods.pause = function ( s )
	openal.alSourcePause ( s.id )
	al_assert ( )
end

source_methods.stop = function ( s )
	openal.alSourceStop ( s.id )
	al_assert ( )
end

source_methods.rewind = function ( s )
	openal.alSourceRewind ( s.id )
	al_assert ( )
end

source_methods.state = function ( s )
	openal.alGetSourcei ( s.id , openal.AL_SOURCE_STATE , int)
	al_assert ( )
	if int[0] == openal_defs.AL_INITIAL then return "initial"
	elseif int[0] == openal_defs.AL_PLAYING then return "playing"
	elseif int[0] == openal_defs.AL_PAUSED then return "paused"
	elseif int[0] == openal_defs.AL_STOPPED then return "stopped"
	else return int[0] end
end

source_methods.queue = function ( s , n , buffer )
	openal.alSourceQueueBuffers ( s.id , n , buffer )
	al_assert ( )
end

source_methods.unqueue = function ( s , n , buffer )
	openal.alSourceUnqueueBuffers ( s.id , n , buffer )
	al_assert ( )
end

source_methods.clear = function ( s )
	openal.alSourcei ( s.id , openal_defs.AL_BUFFER , 0 )
	al_assert ( )
end

source_methods.getvolume = function ( s )
	openal.alGetSourcef ( s.id , openal_defs.AL_GAIN , float )
	al_assert ( )
	return float[0]
end

source_methods.setvolume = function ( s , v )
	openal.alSourcef ( s.id , openal_defs.AL_GAIN , v )
	al_assert ( )
end

source_methods.position = function ( s )
	openal.alGetSourcei ( s.id , openal_defs.AL_SAMPLE_OFFSET , int )
	al_assert ( )
	return int[0]
end

source_methods.position_seconds = function ( s )
	openal.alGetSourcef ( s.id , openal_defs.AL_SEC_OFFSET , float )
	al_assert ( )
	return float[0]
end

source_methods.current_buffer = function ( s )
	openal.alGetSourcei ( s.id , openal_defs.AL_BUFFER , int )
	al_assert ( )
	return int[0]
end


source_mt.__gc = source_methods.delete

-- OpenAL Buffers
function openal.newbuffers ( n )
	local buffers = ffi.new ( "ALuint[?]" , n )
	openal.alGenBuffers ( n , buffers )
	al_assert ( )
	ffi.gc ( buffers , function ( buffers )
			print("GC BUFFERS")
			return openal.alDeleteBuffers ( n , buffers )
		end )
	return buffers
end

function openal.isbuffer ( b )
	local r = openal.alIsBuffer ( b )
	if r == 1 then return true
	elseif r == 0 then return false
	else error()
	end
end

function openal.buffer_info ( b )
	local r = { }
	openal.alGetBufferi ( b , openal_defs.AL_FREQUENCY , int )
	r.frequency = int[0]
	openal.alGetBufferi ( b , openal_defs.AL_SIZE , int )
	r.size = int[0]
	openal.alGetBufferi ( b , openal_defs.AL_BITS , int )
	r.bits = int[0]
	openal.alGetBufferi ( b , openal_defs.AL_CHANNELS , int )
	r.channels = int[0]

	al_assert ( )
	r.frames = r.size / ( r.channels * r.bits/8 )
	r.duration =  r.frames / r.frequency

	return r
end

return openal
