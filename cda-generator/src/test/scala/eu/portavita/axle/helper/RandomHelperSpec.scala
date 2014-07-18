package eu.portavita.axle.helper

import org.scalatest.Matchers
import org.scalatest.FlatSpec

class RandomHelperSpec extends FlatSpec with Matchers {

	"lowercase" should "generate lowercase strings" in {
		val length = 10
		val actual = RandomHelper.lowercase(length)
		assert(actual.size == length)
		for (i <- 0 until length) assert(actual(i).isLower)
	}

	"uppercase" should "generate uppercase strings" in {
		val length = 10
		val actual = RandomHelper.uppercase(length)
		assert(actual.size == length)
		for (i <- 0 until length) assert(actual(i).isUpper)
	}

	"startingWithCapital" should "generate strings starting with upper case and the rest lower case" in {
		val length = 10
		val actual = RandomHelper.startingWithCapital(length)
		assert(actual.size == length)
		assert(actual(0).isUpper)
		for (i <- 1 until length) assert(actual(i).isLower)
	}

	"between" should "generate number in between the given min and max" in {
		val min = 3
		val max = 5
		val actual = RandomHelper.between(min, max)
		assert(actual >= min)
		assert(actual <= max)
	}

	"between" should "generate min when min = max" in {
		val x = 5
		val actual = RandomHelper.between(x, x)
		assert(actual == x)
	}

	"string" should "generate a string with a length between the given min and max" in {
		val min = 3
		val max = 5
		val actual = RandomHelper.string(min, max)
		assert(actual.size >= min)
		assert(actual.size <= max)
	}

	"phrase" should "generate a phrase with the given number of words" in {
		val wordLength = 3
		val words = 4
		val actual = RandomHelper.phrase(words, wordLength, wordLength)(RandomHelper.lowercase)
		assert(actual.size == 15)
	}
}
